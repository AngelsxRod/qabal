import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/format/money.dart';
import '../../domain/errors.dart';
import '../common/describe_error.dart';
import '../common/money_text_field.dart';
import 'account_labels.dart';

/// Crea una cuenta o, si recibe [accountId], edita su nombre y saldo inicial.
/// El tipo y la moneda no cambian una vez creada.
class AccountFormScreen extends ConsumerStatefulWidget {
  const AccountFormScreen({super.key, this.accountId});

  final String? accountId;

  @override
  ConsumerState<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends ConsumerState<AccountFormScreen> {
  final _name = TextEditingController();
  final _balance = TextEditingController();
  AccountType _type = AccountType.cash;
  String _currency = 'GTQ';

  bool _loading = false;
  bool _saving = false;
  String? _originalBalanceText;
  String? _nameError;
  String? _balanceError;
  String? _generalError;

  bool get _isEditing => widget.accountId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loading = true;
      _load();
    }
  }

  Future<void> _load() async {
    final account = await ref.read(accountRepositoryProvider).get(widget.accountId!);
    if (!mounted) return;
    if (account == null) {
      context.pop();
      return;
    }
    setState(() {
      _name.text = account.name;
      _type = account.type;
      _currency = account.currency;
      _originalBalanceText =
          account.initialBalanceMinor == 0 ? '' : formatPlain(account.initialBalanceMinor);
      _balance.text = _originalBalanceText!;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _nameError = _balanceError = _generalError = null;
    });

    // Un saldo que no se tocó se conserva tal cual (puede ser negativo, que
    // el campo no sabe leer).
    final balanceText = _balance.text.trim();
    int? balance;
    var keepBalance = false;
    if (_isEditing && balanceText == _originalBalanceText) {
      keepBalance = true;
    } else if (balanceText.isEmpty) {
      balance = 0;
    } else {
      balance = parseMinor(balanceText);
      if (balance == null) {
        setState(() => _balanceError = invalidAmountMessage);
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(accountRepositoryProvider);
      if (_isEditing) {
        await repo.update(
          widget.accountId!,
          name: _name.text,
          initialBalanceMinor: keepBalance ? null : balance,
        );
      } else {
        await repo.create(AccountInput(
          name: _name.text,
          type: _type,
          currency: _currency,
          initialBalanceMinor: balance ?? 0,
        ));
      }
      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        final message = describeError(e);
        switch (errorFieldOf(e)) {
          case ErrorField.name:
            _nameError = message;
          case ErrorField.amount:
            _balanceError = message;
          default:
            _generalError = message;
        }
      });
      if (e is! DomainException) rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Editar cuenta' : 'Nueva cuenta')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_generalError != null) ...[
                  Text(_generalError!, style: TextStyle(color: theme.colorScheme.error)),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() => _nameError = null),
                  decoration: InputDecoration(labelText: 'Nombre', errorText: _nameError),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<AccountType>(
                  isExpanded: true,
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: [
                    for (final t in AccountType.values)
                      DropdownMenuItem(
                        value: t,
                        // Las tarjetas se habilitan en una fase posterior.
                        enabled: t != AccountType.creditCard,
                        child: Text(
                          t == AccountType.creditCard
                              ? '${accountTypeLabel(t)} · Próximamente'
                              : accountTypeLabel(t),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _isEditing ? null : (t) => setState(() => _type = t ?? _type),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _currency,
                  decoration: const InputDecoration(labelText: 'Moneda'),
                  items: [
                    for (final c in {...accountCurrencies, _currency})
                      DropdownMenuItem(value: c, child: Text('$c (${currencySymbol(c)})')),
                  ],
                  onChanged:
                      _isEditing ? null : (c) => setState(() => _currency = c ?? _currency),
                ),
                const SizedBox(height: 16),
                MoneyTextField(
                  controller: _balance,
                  label: 'Saldo inicial',
                  currency: _currency,
                  errorText: _balanceError,
                  helperText: 'Lo que tiene la cuenta hoy. Déjalo vacío si empieza en cero.',
                  onChanged: (_) => setState(() => _balanceError = null),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_isEditing ? 'Guardar cambios' : 'Crear cuenta'),
                ),
              ],
            ),
    );
  }
}
