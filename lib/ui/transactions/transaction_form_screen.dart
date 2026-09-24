import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../domain/clock.dart';
import '../../domain/errors.dart';
import '../accounts/account_labels.dart';
import '../common/async_body.dart';
import '../common/confirm_dialog.dart';
import '../common/describe_error.dart';
import '../common/money_text_field.dart';
import 'transaction_labels.dart';

/// Marca del valor "Nuevo…" dentro de los selectores.
const _createNew = '__new__';

/// Registra un movimiento (gasto, ingreso o transferencia) o, si recibe
/// [transactionId], lo edita o elimina.
class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({
    super.key,
    this.transactionId,
    this.initialAccountId,
    this.initialType,
  });

  final String? transactionId;
  final String? initialAccountId;
  final TransactionType? initialType;

  @override
  ConsumerState<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _amount = TextEditingController();
  final _destAmount = TextEditingController();
  final _note = TextEditingController();

  late TransactionType _type;
  String? _accountId;
  String? _destinationId;
  String? _categoryId;
  String? _contactId;
  late DateTime _date;
  Set<String> _tagIds = {};

  /// Movimiento original al editar: de él se conserva lo que el formulario no
  /// muestra (deuda, estado de cuenta, comprobante) porque `update` reemplaza
  /// todos los campos.
  Transaction? _existing;
  bool _loading = false;
  bool _saving = false;
  final Map<ErrorField, String> _errors = {};

  bool get _isEditing => widget.transactionId != null;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType ?? TransactionType.expense;
    _accountId = widget.initialAccountId;
    _date = ref.read(dayProvider);
    if (_isEditing) {
      _loading = true;
      _load();
    }
  }

  Future<void> _load() async {
    final tx = await ref.read(transactionRepositoryProvider).get(widget.transactionId!);
    if (!mounted) return;
    if (tx == null) {
      context.pop();
      return;
    }
    final tags = await ref.read(tagRepositoryProvider).tagsOf(tx.id);
    if (!mounted) return;
    setState(() {
      _existing = tx;
      _type = tx.type;
      _accountId = tx.accountId;
      _destinationId = tx.transferAccountId;
      _categoryId = tx.categoryId;
      _contactId = tx.contactId;
      _date = dateOnly(tx.occurredAt);
      _amount.text = formatPlain(tx.amountMinor);
      if (tx.transferAmountMinor != null) {
        _destAmount.text = formatPlain(tx.transferAmountMinor!);
      }
      _note.text = tx.note ?? '';
      _tagIds = tags.map((t) => t.id).toSet();
      _loading = false;
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _destAmount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _clearError(ErrorField field) {
    if (_errors.containsKey(field)) setState(() => _errors.remove(field));
  }

  // ---------------------------------------------------------------------
  // Guardar y eliminar
  // ---------------------------------------------------------------------

  Future<void> _save(Map<String, Account> accounts) async {
    final errors = <ErrorField, String>{};
    final source = accounts[_accountId];
    final dest = accounts[_destinationId];
    final isTransfer = _type == TransactionType.transfer;

    int? amount;
    final amountText = _amount.text.trim();
    if (amountText.isEmpty) {
      errors[ErrorField.amount] = 'Escribe un monto';
    } else {
      amount = parseMinor(amountText);
      if (amount == null) errors[ErrorField.amount] = invalidAmountMessage;
    }
    if (source == null) errors[ErrorField.account] = 'Elige una cuenta';

    int? destAmount;
    if (isTransfer) {
      if (dest == null) {
        errors[ErrorField.destination] = 'Elige la cuenta destino';
      } else if (source != null && source.currency != dest.currency) {
        final text = _destAmount.text.trim();
        if (text.isEmpty) {
          errors[ErrorField.transferAmount] = 'Escribe el monto que llega';
        } else {
          destAmount = parseMinor(text);
          if (destAmount == null) {
            errors[ErrorField.transferAmount] = invalidAmountMessage;
          }
        }
      }
    }

    if (errors.isNotEmpty) {
      setState(() {
        _errors
          ..clear()
          ..addAll(errors);
      });
      return;
    }

    final existing = _existing;
    final keepsTime = existing != null && dateOnly(existing.occurredAt) == _date;
    final input = TransactionInput(
      accountId: source!.id,
      type: _type,
      amountMinor: amount!,
      occurredAt: keepsTime ? existing.occurredAt : _date,
      categoryId: isTransfer ? null : _categoryId,
      transferAccountId: isTransfer ? dest!.id : null,
      transferAmountMinor: isTransfer ? destAmount : null,
      contactId: isTransfer ? null : _contactId,
      debtId: existing?.debtId,
      // El vínculo con un estado de cuenta solo sobrevive si sigue siendo el
      // mismo pago a la misma tarjeta.
      statementId: isTransfer && dest!.id == existing?.transferAccountId
          ? existing?.statementId
          : null,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      receiptPath: existing?.receiptPath,
    );

    setState(() {
      _errors.clear();
      _saving = true;
    });
    try {
      final repo = ref.read(transactionRepositoryProvider);
      if (_isEditing) {
        await repo.update(widget.transactionId!, input, tagIds: _tagIds);
      } else {
        await repo.create(input, tagIds: _tagIds);
      }
      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errors[errorFieldOf(
          e,
          sourceAccountId: _accountId,
          destinationAccountId: _destinationId,
        )] = describeError(
          e,
        );
      });
      if (e is! DomainException) rethrow;
    }
  }

  Future<void> _delete() async {
    final confirmed = await confirmAction(
      context,
      title: 'Eliminar movimiento',
      message: 'Se borrará definitivamente y el saldo de la cuenta se recalculará.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(transactionRepositoryProvider).delete(widget.transactionId!);
      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errors[ErrorField.general] = describeError(e));
      if (e is! DomainException) rethrow;
    }
  }

  // ---------------------------------------------------------------------
  // Alta rápida de contactos y etiquetas
  // ---------------------------------------------------------------------

  Future<String?> _askName(String title, String label) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: label),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  Future<void> _createContact() async {
    final name = await _askName('Nuevo contacto', 'Nombre');
    if (name == null || !mounted) return;
    try {
      final contact = await ref.read(contactRepositoryProvider).create(ContactInput(name: name));
      setState(() => _contactId = contact.id);
    } on DomainException catch (e) {
      _snack(describeError(e));
    }
  }

  Future<void> _createTag() async {
    final name = await _askName('Nueva etiqueta', 'Nombre');
    if (name == null || !mounted) return;
    try {
      final tag = await ref.read(tagRepositoryProvider).create(name);
      setState(() => _tagIds = {..._tagIds, tag.id});
    } on DomainException catch (e) {
      _snack(describeError(e));
    }
  }

  void _snack(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _pickDate() async {
    final today = ref.read(dayProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year + 1, today.month, today.day),
    );
    if (picked != null) setState(() => _date = dateOnly(picked));
  }

  // ---------------------------------------------------------------------
  // Interfaz
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountBalancesProvider(true));
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar movimiento' : 'Nuevo movimiento'),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Eliminar',
              icon: const Icon(Icons.delete_outline),
              onPressed: _loading ? null : _delete,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : AsyncBody(value: accountsAsync, data: (all) => _buildForm(context, all)),
    );
  }

  Widget _buildForm(BuildContext context, List<AccountBalance> all) {
    final theme = Theme.of(context);
    final accounts = {
      for (final b in all)
        if (isPlainAccount(b.account)) b.account.id: b.account,
    };
    final catalogs = [
      ref.watch(categoriesProvider),
      ref.watch(contactsProvider),
      ref.watch(tagsProvider),
    ];
    final failed = catalogs.where((c) => c.hasError).firstOrNull;
    if (failed != null) return Center(child: Text(describeError(failed.error!)));
    // Los selectores necesitan sus catálogos completos para mostrar el valor
    // que ya tiene el movimiento.
    if (catalogs.any((c) => !c.hasValue)) {
      return const Center(child: CircularProgressIndicator());
    }
    final categories = ref.watch(categoriesProvider).requireValue;
    final contacts = ref.watch(contactsProvider).requireValue;
    final tags = ref.watch(tagsProvider).requireValue;

    final source = accounts[_accountId];
    final dest = accounts[_destinationId];
    final isTransfer = _type == TransactionType.transfer;
    final crossCurrency =
        isTransfer && source != null && dest != null && source.currency != dest.currency;

    // Solo cuentas activas; se conserva la que ya usa el movimiento al editar.
    bool selectable(Account a) =>
        !a.isArchived || a.id == _existing?.accountId || a.id == _existing?.transferAccountId;
    final selectableAccounts = accounts.values.where(selectable).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final categoriesById = {for (final c in categories) c.id: c};
    final kind = _type == TransactionType.income ? CategoryKind.income : CategoryKind.expense;
    final visibleCategories =
        categories.where((c) => c.kind == kind && (!c.isArchived || c.id == _categoryId)).toList()
          ..sort(
            (a, b) => categoryLabel(
              a,
              categoriesById,
            ).toLowerCase().compareTo(categoryLabel(b, categoriesById).toLowerCase()),
          );
    final visibleContacts = contacts.where((c) => !c.isArchived || c.id == _contactId).toList();
    final showCategory = !isTransfer && _existing?.debtId == null;

    final general = _errors[ErrorField.general];

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (general != null) ...[
          Text(general, style: TextStyle(color: theme.colorScheme.error)),
          const SizedBox(height: 12),
        ],
        SegmentedButton<TransactionType>(
          segments: [
            for (final t in TransactionType.values)
              ButtonSegment(value: t, label: Text(transactionTypeLabel(t))),
          ],
          selected: {_type},
          showSelectedIcon: false,
          // Sin íconos y compacto: en 320 dp "Transferencia" no cabe si no.
          style: SegmentedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            textStyle: const TextStyle(fontSize: 13),
          ),
          onSelectionChanged: (s) => setState(() {
            _type = s.first;
            _errors.clear();
            if (_type == TransactionType.transfer) {
              _categoryId = null;
              _contactId = null;
            } else {
              _destinationId = null;
              _destAmount.clear();
              final c = categoriesById[_categoryId];
              if (c != null &&
                  c.kind !=
                      (_type == TransactionType.income
                          ? CategoryKind.income
                          : CategoryKind.expense)) {
                _categoryId = null;
              }
            }
          }),
        ),
        const SizedBox(height: 16),
        _accountDropdown(
          keyName: 'field-account',
          label: isTransfer ? 'Cuenta origen' : 'Cuenta',
          value: _accountId,
          accounts: selectableAccounts,
          errorText: _errors[ErrorField.account],
          onChanged: (id) => setState(() {
            _accountId = id;
            _errors.remove(ErrorField.account);
            if (_destinationId == id) _destinationId = null;
          }),
        ),
        if (isTransfer) ...[
          const SizedBox(height: 16),
          _accountDropdown(
            keyName: 'field-destination',
            label: 'Cuenta destino',
            value: _destinationId,
            accounts: selectableAccounts.where((a) => a.id != _accountId).toList(),
            errorText: _errors[ErrorField.destination],
            onChanged: (id) => setState(() {
              _destinationId = id;
              _errors.remove(ErrorField.destination);
            }),
          ),
        ],
        const SizedBox(height: 16),
        MoneyTextField(
          controller: _amount,
          label: 'Monto',
          currency: source?.currency,
          errorText: _errors[ErrorField.amount],
          textInputAction: TextInputAction.next,
          onChanged: (_) => _clearError(ErrorField.amount),
        ),
        if (crossCurrency) ...[
          const SizedBox(height: 16),
          MoneyTextField(
            controller: _destAmount,
            label: 'Monto que llega',
            currency: dest.currency,
            helperText: 'Las cuentas tienen monedas distintas: indica lo que recibe el destino.',
            errorText: _errors[ErrorField.transferAmount],
            onChanged: (_) => _clearError(ErrorField.transferAmount),
          ),
        ],
        if (showCategory) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            key: Key('field-category-$_type-$_categoryId'),
            isExpanded: true,
            initialValue: visibleCategories.any((c) => c.id == _categoryId) ? _categoryId : null,
            decoration: InputDecoration(
              labelText: 'Categoría',
              errorText: _errors[ErrorField.category],
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Sin categoría')),
              for (final c in visibleCategories)
                DropdownMenuItem(
                  value: c.id,
                  child: Text(categoryLabel(c, categoriesById), overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (id) => setState(() {
              _categoryId = id;
              _errors.remove(ErrorField.category);
            }),
          ),
        ],
        if (!isTransfer) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            key: Key('field-contact-$_contactId-${visibleContacts.length}'),
            isExpanded: true,
            initialValue: visibleContacts.any((c) => c.id == _contactId) ? _contactId : null,
            decoration: InputDecoration(
              labelText: _type == TransactionType.income ? 'Fuente' : 'Contacto',
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Ninguno')),
              for (final c in visibleContacts)
                DropdownMenuItem(
                  value: c.id,
                  child: Text(c.name, overflow: TextOverflow.ellipsis),
                ),
              const DropdownMenuItem(value: _createNew, child: Text('Nuevo contacto…')),
            ],
            onChanged: (id) {
              if (id == _createNew) {
                _createContact();
              } else {
                setState(() => _contactId = id);
              }
            },
          ),
        ],
        const SizedBox(height: 16),
        InkWell(
          onTap: _pickDate,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Fecha',
              suffixIcon: Icon(Icons.calendar_today_outlined),
            ),
            child: Text(formatDate(_date)),
          ),
        ),
        const SizedBox(height: 16),
        Text('Etiquetas', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final t in tags.where((t) => !t.isArchived || _tagIds.contains(t.id)))
              FilterChip(
                label: Text(t.name),
                selected: _tagIds.contains(t.id),
                onSelected: (on) => setState(() {
                  _tagIds = on ? {..._tagIds, t.id} : ({..._tagIds}..remove(t.id));
                }),
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Nueva etiqueta'),
              onPressed: _createTag,
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _note,
          minLines: 1,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Nota'),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _saving ? null : () => _save(accounts),
          child: Text(
            _isEditing ? 'Guardar cambios' : 'Guardar ${transactionTypeLabel(_type).toLowerCase()}',
          ),
        ),
      ],
    );
  }

  Widget _accountDropdown({
    required String keyName,
    required String label,
    required String? value,
    required List<Account> accounts,
    required String? errorText,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      key: Key('$keyName-$value'),
      isExpanded: true,
      initialValue: accounts.any((a) => a.id == value) ? value : null,
      decoration: InputDecoration(labelText: label, errorText: errorText),
      items: [
        for (final a in accounts)
          DropdownMenuItem(
            value: a.id,
            child: Text(
              '${a.name} · ${accountTypeLabel(a.type)} (${a.currency})',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
