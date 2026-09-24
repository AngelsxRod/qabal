import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/format/money.dart';
import '../../core/format/money_input.dart';
import '../../domain/errors.dart';
import '../common/describe_error.dart';
import '../design/amount_input.dart';
import '../design/app_button.dart';
import '../design/bottom_action_bar.dart';
import '../design/option_chips.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
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
      _originalBalanceText = account.initialBalanceMinor == 0
          ? ''
          : account.initialBalanceMinor < 0
          ? formatPlain(account.initialBalanceMinor)
          : formatGrouped(account.initialBalanceMinor);
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
    setState(() => _nameError = _balanceError = _generalError = null);

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
      balance = parseInputMinor(balanceText);
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
        await repo.create(
          AccountInput(
            name: _name.text,
            type: _type,
            currency: _currency,
            initialBalanceMinor: balance ?? 0,
          ),
        );
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
    final c = context.colors;
    final t = context.text;
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Editar cuenta' : 'Nueva cuenta')),
      bottomNavigationBar: _loading
          ? null
          : BottomActionBar(
              child: AppButton(
                label: _isEditing ? 'Guardar cambios' : 'Crear cuenta',
                loading: _saving,
                onPressed: _save,
              ),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xl),
              children: [
                if (_generalError != null) ...[
                  Text(_generalError!, style: t.caption.copyWith(color: c.danger)),
                  const SizedBox(height: Space.md),
                ],
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() => _nameError = null),
                  decoration: InputDecoration(labelText: 'Nombre', errorText: _nameError),
                ),
                const SizedBox(height: Space.xl),
                Text('TIPO', style: t.label),
                const SizedBox(height: Space.sm),
                OptionChips<AccountType>(
                  enabled: !_isEditing,
                  value: _type,
                  onChanged: (v) => setState(() => _type = v),
                  options: [
                    for (final type in AccountType.values)
                      Option(
                        type,
                        type == AccountType.creditCard
                            // Las tarjetas se habilitan en una fase posterior.
                            ? '${accountTypeLabel(type)} · Próximamente'
                            : accountTypeLabel(type),
                        enabled: type != AccountType.creditCard,
                      ),
                  ],
                ),
                const SizedBox(height: Space.xl),
                Text('MONEDA', style: t.label),
                const SizedBox(height: Space.sm),
                OptionChips<String>(
                  enabled: !_isEditing,
                  value: _currency,
                  onChanged: (v) => setState(() => _currency = v),
                  options: [
                    for (final cur in {...accountCurrencies, _currency})
                      Option(cur, '$cur (${currencySymbol(cur)})'),
                  ],
                ),
                const SizedBox(height: Space.xl),
                Text('SALDO INICIAL', style: t.label),
                const SizedBox(height: Space.xs),
                AmountInput(
                  controller: _balance,
                  currency: _currency,
                  label: 'Saldo inicial',
                  large: false,
                  errorText: _balanceError,
                  onChanged: (_) => setState(() => _balanceError = null),
                ),
                const SizedBox(height: Space.xs),
                Text(
                  'Lo que tiene la cuenta hoy. Déjalo vacío si empieza en cero.',
                  style: t.caption,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
    );
  }
}
