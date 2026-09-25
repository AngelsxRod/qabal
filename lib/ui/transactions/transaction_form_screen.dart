import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/format/dates.dart';
import '../../core/format/money_input.dart';
import '../../domain/clock.dart';
import '../../domain/errors.dart';
import '../accounts/account_labels.dart';
import '../categories/category_order.dart';
import '../common/async_body.dart';
import '../common/confirm_dialog.dart';
import '../common/describe_error.dart';
import '../common/name_dialog.dart';
import '../design/account_chips.dart';
import '../design/amount_input.dart';
import '../design/app_button.dart';
import '../design/app_card.dart';
import '../design/bottom_action_bar.dart';
import '../design/category_avatar.dart';
import '../design/category_picker.dart';
import '../design/category_style.dart';
import '../design/empty_state.dart';
import '../design/picker_row.dart';
import '../design/tokens.dart';
import '../design/type_switcher.dart';
import '../design/typography.dart';
import 'transaction_labels.dart';

/// Valores especiales de la hoja de contactos.
const _noContact = '';
const _newContact = '__new__';

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
  bool _moreOpen = false;

  /// Cuenta del último movimiento registrado: va primera y preseleccionada.
  String? _lastUsedId;

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
    } else {
      _loadLastUsed();
    }
  }

  Future<void> _loadLastUsed() async {
    final latest = await ref
        .read(transactionRepositoryProvider)
        .list(const TransactionFilter(limit: 1));
    if (!mounted || latest.isEmpty) return;
    setState(() {
      _lastUsedId = latest.first.accountId;
      _accountId ??= _lastUsedId;
    });
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
      _amount.text = formatGrouped(tx.amountMinor);
      if (tx.transferAmountMinor != null) {
        _destAmount.text = formatGrouped(tx.transferAmountMinor!);
      }
      _note.text = tx.note ?? '';
      _tagIds = tags.map((t) => t.id).toSet();
      _moreOpen = tx.contactId != null || tags.isNotEmpty || (tx.note ?? '').isNotEmpty;
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
      amount = parseInputMinor(amountText);
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
          destAmount = parseInputMinor(text);
          if (destAmount == null) errors[ErrorField.transferAmount] = invalidAmountMessage;
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
  // Selectores y alta rápida de contactos y etiquetas
  // ---------------------------------------------------------------------

  Future<void> _pickContact(List<Contact> contacts) async {
    // Sin esto, al cerrar el selector el foco vuelve al monto y sube el teclado.
    FocusScope.of(context).unfocus();
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _ContactSheet(
        title: _type == TransactionType.income ? 'Fuente' : 'Contacto',
        contacts: contacts,
        selectedId: _contactId,
      ),
    );
    if (picked == null || !mounted) return;
    if (picked == _newContact) {
      await _createContact();
    } else {
      setState(() => _contactId = picked == _noContact ? null : picked);
    }
  }

  Future<void> _createContact() => showNameDialog(
    context,
    title: 'Nuevo contacto',
    confirmLabel: 'Crear',
    onSubmit: (name) async {
      final contact = await ref.read(contactRepositoryProvider).create(ContactInput(name: name));
      if (mounted) setState(() => _contactId = contact.id);
    },
  );

  Future<void> _createTag() => showNameDialog(
    context,
    title: 'Nueva etiqueta',
    confirmLabel: 'Crear',
    onSubmit: (name) async {
      final tag = await ref.read(tagRepositoryProvider).create(name);
      if (mounted) setState(() => _tagIds = {..._tagIds, tag.id});
    },
  );

  Future<void> _pickDate() async {
    // Sin esto, al cerrar el selector el foco vuelve al monto y sube el teclado.
    FocusScope.of(context).unfocus();
    final today = ref.read(dayProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year + 1, today.month, today.day),
    );
    if (picked != null) setState(() => _date = dateOnly(picked));
  }

  Future<void> _pickCategory(List<Category> options, Map<String, Category> byId) async {
    // Sin esto, al cerrar el selector el foco vuelve al monto y sube el teclado.
    FocusScope.of(context).unfocus();
    final pick = await showCategoryPicker(
      context,
      categories: options,
      selectedId: _categoryId,
      labelOf: (c) => categoryLabel(c, byId),
    );
    if (pick == null) return;
    setState(() {
      _categoryId = pick.id;
      _errors.remove(ErrorField.category);
    });
  }

  String _dateLabel() {
    final today = ref.read(dayProvider);
    final diff = DateTime.utc(
      today.year,
      today.month,
      today.day,
    ).difference(DateTime.utc(_date.year, _date.month, _date.day)).inDays;
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Ayer';
    return formatDate(_date);
  }

  // ---------------------------------------------------------------------
  // Interfaz
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountBalancesProvider(true));
    final accounts = accountsAsync.value == null
        ? null
        : {
            for (final b in accountsAsync.requireValue)
              if (isPlainAccount(b.account)) b.account.id: b.account,
          };
    final noAccounts = accounts != null && accounts.isEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar movimiento' : 'Nuevo movimiento'),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Eliminar',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _loading ? null : _delete,
            ),
        ],
      ),
      bottomNavigationBar: _loading || accounts == null || noAccounts
          ? null
          : BottomActionBar(
              child: AppButton(
                label: _isEditing
                    ? 'Guardar cambios'
                    : 'Guardar ${transactionTypeLabel(_type).toLowerCase()}',
                loading: _saving,
                onPressed: () => _save(accounts),
              ),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : AsyncBody(
              value: accountsAsync,
              data: (_) => noAccounts
                  ? EmptyState(
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'Primero crea una cuenta',
                      message: 'Necesitas al menos una cuenta para registrar movimientos.',
                      actionLabel: 'Crear cuenta',
                      onAction: () => context.push(Routes.accountNew),
                    )
                  : _buildForm(context, accounts!),
            ),
    );
  }

  Widget _buildForm(BuildContext context, Map<String, Account> accounts) {
    final c = context.colors;
    final t = context.text;
    final brightness = Theme.of(context).brightness;
    final catalogs = [
      ref.watch(categoriesProvider),
      ref.watch(contactsProvider),
      ref.watch(tagsProvider),
    ];
    final failed = catalogs.where((x) => x.hasError).firstOrNull;
    if (failed != null) return Center(child: Text(describeError(failed.error!)));
    // Los selectores necesitan sus catálogos completos para mostrar el valor
    // que ya tiene el movimiento.
    if (catalogs.any((x) => !x.hasValue)) {
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

    // Solo cuentas activas (más la que ya usa el movimiento al editar); la
    // última usada va primero.
    bool selectable(Account a) =>
        !a.isArchived || a.id == _existing?.accountId || a.id == _existing?.transferAccountId;
    final selectableAccounts = accounts.values.where(selectable).toList()
      ..sort((a, b) {
        // Al editar va primero la cuenta del movimiento (que se vea elegida);
        // al crear, la última usada.
        final first = _isEditing ? _existing?.accountId : _lastUsedId;
        if (a.id == first) return -1;
        if (b.id == first) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    final categoriesById = {for (final x in categories) x.id: x};
    final kind = _type == TransactionType.income ? CategoryKind.income : CategoryKind.expense;
    final visibleCategories = orderForPicker([
      for (final x in categories)
        if (x.kind == kind && (!x.isArchived || x.id == _categoryId)) x,
    ]);
    final visibleContacts = contacts.where((x) => !x.isArchived || x.id == _contactId).toList();
    final showCategory = !isTransfer && _existing?.debtId == null;
    final selectedCategory = categoriesById[_categoryId];
    final categoryStyle = categoryStyleFor(selectedCategory, brightness);
    final contactName = contacts.where((x) => x.id == _contactId).firstOrNull?.name;
    final general = _errors[ErrorField.general];

    Widget label(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, Space.sm),
      child: Text(text, style: t.label),
    );
    Widget padded(Widget w) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: w,
    );

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(top: Space.sm, bottom: Space.xxl),
      children: [
        if (general != null)
          padded(
            Padding(
              padding: const EdgeInsets.only(bottom: Space.md),
              child: Text(general, style: t.caption.copyWith(color: c.danger)),
            ),
          ),
        padded(
          TypeSwitcher<TransactionType>(
            value: _type,
            options: [
              for (final ty in [
                TransactionType.expense,
                TransactionType.income,
                TransactionType.transfer,
              ])
                (ty, transactionTypeLabel(ty)),
            ],
            colorOf: (ty) => transactionTypeColor(context, ty),
            onChanged: (ty) => setState(() {
              _type = ty;
              _errors.clear();
              if (ty == TransactionType.transfer) {
                _categoryId = null;
                _contactId = null;
              } else {
                _destinationId = null;
                _destAmount.clear();
                final cat = categoriesById[_categoryId];
                final expected = ty == TransactionType.income
                    ? CategoryKind.income
                    : CategoryKind.expense;
                if (cat != null && cat.kind != expected) _categoryId = null;
              }
            }),
          ),
        ),
        const SizedBox(height: Space.xl),
        padded(
          AmountInput(
            controller: _amount,
            currency: source?.currency,
            autofocus: !_isEditing,
            errorText: _errors[ErrorField.amount],
            onChanged: (_) => _clearError(ErrorField.amount),
          ),
        ),
        if (crossCurrency) ...[
          const SizedBox(height: Space.lg),
          padded(Text('Monto que llega', style: t.label, textAlign: TextAlign.center)),
          padded(
            AmountInput(
              controller: _destAmount,
              currency: dest.currency,
              label: 'Monto que llega',
              large: false,
              errorText: _errors[ErrorField.transferAmount],
              onChanged: (_) => _clearError(ErrorField.transferAmount),
            ),
          ),
        ],
        label(isTransfer ? 'DESDE' : 'CUENTA'),
        AccountChips(
          accounts: selectableAccounts,
          selectedId: _accountId,
          errorText: _errors[ErrorField.account],
          onSelected: (id) => setState(() {
            _accountId = id;
            _errors.remove(ErrorField.account);
            if (_destinationId == id) _destinationId = null;
          }),
        ),
        if (isTransfer) ...[
          label('HACIA'),
          AccountChips(
            accounts: [
              for (final a in selectableAccounts)
                if (a.id != _accountId && a.id == _existing?.transferAccountId) a,
              for (final a in selectableAccounts)
                if (a.id != _accountId && a.id != _existing?.transferAccountId) a,
            ],
            selectedId: _destinationId,
            errorText: _errors[ErrorField.destination],
            onSelected: (id) => setState(() {
              _destinationId = id;
              _errors.remove(ErrorField.destination);
            }),
          ),
        ],
        const SizedBox(height: Space.xl),
        padded(
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                if (showCategory) ...[
                  PickerRow(
                    label: 'Categoría',
                    value: selectedCategory == null
                        ? 'Elegir categoría'
                        : categoryLabel(selectedCategory, categoriesById),
                    placeholder: selectedCategory == null,
                    errorText: _errors[ErrorField.category],
                    leading: CategoryAvatar(
                      icon: categoryStyle.icon,
                      color: categoryStyle.color,
                      size: 36,
                    ),
                    onTap: () => _pickCategory(visibleCategories, categoriesById),
                  ),
                  Divider(color: c.border),
                ],
                PickerRow(
                  label: 'Fecha',
                  value: _dateLabel(),
                  leading: SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(Icons.calendar_today_rounded, color: c.textSecondary, size: 22),
                  ),
                  onTap: _pickDate,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.sm),
        padded(
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _moreOpen = !_moreOpen),
              icon: Icon(_moreOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded),
              label: Text(_moreOpen ? 'Menos detalles' : 'Más detalles'),
            ),
          ),
        ),
        if (_moreOpen) ...[
          if (!isTransfer)
            padded(
              AppCard(
                padding: EdgeInsets.zero,
                child: PickerRow(
                  label: _type == TransactionType.income ? 'Fuente' : 'Contacto',
                  value: contactName ?? 'Ninguno',
                  placeholder: contactName == null,
                  leading: SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(Icons.person_outline_rounded, color: c.textSecondary, size: 22),
                  ),
                  onTap: () => _pickContact(visibleContacts),
                ),
              ),
            ),
          label('ETIQUETAS'),
          padded(
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final tag in tags.where((x) => !x.isArchived || _tagIds.contains(x.id)))
                  FilterChip(
                    label: Text(tag.name),
                    selected: _tagIds.contains(tag.id),
                    showCheckmark: false,
                    onSelected: (on) => setState(() {
                      _tagIds = on ? {..._tagIds, tag.id} : ({..._tagIds}..remove(tag.id));
                    }),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Nueva etiqueta'),
                  onPressed: _createTag,
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.lg),
          padded(
            TextField(
              controller: _note,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nota'),
            ),
          ),
        ],
      ],
    );
  }
}

/// Hoja con los contactos para elegir uno, quitarlo o crear otro.
class _ContactSheet extends StatelessWidget {
  const _ContactSheet({required this.title, required this.contacts, required this.selectedId});

  final String title;
  final List<Contact> contacts;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    Widget row(String text, String value, {IconData? icon, bool selected = false}) => ListTile(
      minTileHeight: kMinTap + 8,
      leading: Icon(icon ?? Icons.person_outline_rounded, color: c.textSecondary),
      title: Text(text, style: t.bodyStrong),
      trailing: selected ? Icon(Icons.check_rounded, color: c.accent) : null,
      onTap: () => Navigator.of(context).pop(value),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.sm),
          child: Text(title, style: t.heading),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              row('Ninguno', _noContact, icon: Icons.block_rounded, selected: selectedId == null),
              for (final ct in contacts) row(ct.name, ct.id, selected: ct.id == selectedId),
              row('Nuevo contacto…', _newContact, icon: Icons.add_rounded),
            ],
          ),
        ),
        const SizedBox(height: Space.lg),
      ],
    );
  }
}
