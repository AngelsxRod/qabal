import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/format/money_input.dart';
import '../../domain/credit_card/card_cycle.dart';
import '../../domain/credit_card/card_schedule.dart';
import '../../domain/errors.dart';
import '../common/describe_error.dart';
import '../design/amount_input.dart';
import '../design/app_button.dart';
import '../design/bottom_action_bar.dart';
import '../design/info_note.dart';
import '../design/option_chips.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'account_labels.dart';

/// Crea una cuenta o, si recibe [accountId], edita su nombre y saldo inicial
/// (en una tarjeta, también su límite, sus días de corte y pago y su pago
/// mínimo). El tipo y la moneda no cambian una vez creada.
class AccountFormScreen extends ConsumerStatefulWidget {
  const AccountFormScreen({super.key, this.accountId, this.initialType});

  final String? accountId;

  /// Tipo preseleccionado al crear (por ejemplo, desde "Nueva tarjeta").
  final AccountType? initialType;

  @override
  ConsumerState<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends ConsumerState<AccountFormScreen> {
  final _name = TextEditingController();
  final _balance = TextEditingController();
  final _limit = TextEditingController();
  final _statementDay = TextEditingController();
  final _dueDay = TextEditingController();
  final _minPercent = TextEditingController();
  final _scroll = ScrollController();
  late AccountType _type = widget.initialType ?? AccountType.cash;
  String _currency = 'GTQ';

  bool _loading = false;
  bool _saving = false;
  String? _originalBalanceText;
  String? _nameError;
  String? _balanceError;
  String? _limitError;
  String? _daysError;
  String? _minError;
  String? _generalError;

  bool get _isEditing => widget.accountId != null;
  bool get _isCard => _type == AccountType.creditCard;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loading = true;
      _load();
    }
  }

  Future<void> _load() async {
    final repo = ref.read(accountRepositoryProvider);
    final account = await repo.get(widget.accountId!);
    if (!mounted) return;
    if (account == null) {
      context.pop();
      return;
    }
    final card = account.type == AccountType.creditCard
        ? await repo.cardSettings(account.id)
        : null;
    if (!mounted) return;
    final initial = account.initialBalanceMinor;
    setState(() {
      _name.text = account.name;
      _type = account.type;
      _currency = account.currency;
      if (account.type == AccountType.creditCard) {
        // En una tarjeta se escribe la deuda (positiva); se guarda negativa.
        _originalBalanceText = initial == 0
            ? ''
            : initial < 0
            ? formatGrouped(-initial)
            : formatPlain(-initial);
      } else {
        _originalBalanceText = initial == 0
            ? ''
            : initial < 0
            ? formatPlain(initial)
            : formatGrouped(initial);
      }
      _balance.text = _originalBalanceText!;
      if (card != null) {
        _limit.text = formatGrouped(card.creditLimitMinor);
        _statementDay.text = '${card.statementDay}';
        _dueDay.text = '${card.dueDay}';
        final bp = card.minPaymentBp;
        _minPercent.text = bp == null
            ? ''
            : bp % 100 == 0
            ? '${bp ~/ 100}'
            : '${bp / 100}';
      }
      _loading = false;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    _limit.dispose();
    _statementDay.dispose();
    _dueDay.dispose();
    _minPercent.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Día de 1 a 31 escrito en [c], o `null`.
  int? _dayOf(TextEditingController c) {
    final v = int.tryParse(c.text.trim());
    return v != null && v >= 1 && v <= 31 ? v : null;
  }

  Future<void> _save() async {
    setState(() {
      _nameError = _balanceError = _limitError = _daysError = _minError = _generalError = null;
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
      balance = parseInputMinor(balanceText);
      if (balance == null) {
        setState(() => _balanceError = invalidAmountMessage);
        return;
      }
    }
    // Deuda actual (positiva) → saldo inicial negativo.
    if (_isCard && balance != null) balance = -balance;

    CreditCardSettings? card;
    if (_isCard) {
      String? limitError;
      String? daysError;
      String? minError;
      final limit = parseInputMinor(_limit.text.trim());
      if (_limit.text.trim().isEmpty) {
        limitError = 'Escribe el límite de crédito';
      } else if (limit == null) {
        limitError = invalidAmountMessage;
      } else if (limit <= 0) {
        limitError = 'El límite debe ser mayor que cero';
      }
      final statementDay = _dayOf(_statementDay);
      final dueDay = _dayOf(_dueDay);
      if (statementDay == null || dueDay == null) {
        daysError = 'Escribe el día de corte y el de pago (de 1 a 31)';
      }
      int? bp;
      final pct = _minPercent.text.trim().replaceAll(',', '.');
      if (pct.isNotEmpty) {
        final v = double.tryParse(pct);
        if (v == null || v < 0 || v > 100) {
          minError = 'Escribe un porcentaje de 0 a 100';
        } else {
          bp = (v * 100).round();
        }
      }
      if (limitError != null || daysError != null || minError != null) {
        setState(() {
          _limitError = limitError;
          _daysError = daysError;
          _minError = minError;
        });
        return;
      }
      card = CreditCardSettings(
        creditLimitMinor: limit!,
        statementDay: statementDay!,
        dueDay: dueDay!,
        minPaymentBp: bp,
      );
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
        if (card != null) await repo.updateCardSettings(widget.accountId!, card);
      } else {
        await repo.create(
          AccountInput(
            name: _name.text,
            type: _type,
            currency: _currency,
            initialBalanceMinor: balance ?? 0,
          ),
          card: card,
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
            // El nombre es el primer campo: en un formulario largo (tarjeta) su
            // error quedaría fuera de pantalla.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scroll.hasClients) {
                _scroll.animateTo(
                  0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                );
              }
            });
          case ErrorField.amount:
            _balanceError = message;
          case ErrorField.cardSchedule:
            _daysError = message;
          default:
            _generalError = message;
        }
      });
      if (e is! DomainException) rethrow;
    }
  }

  /// "Próximo corte: 21 oct · Pago hasta: 15 nov" con los días escritos, o
  /// `null` si todavía no forman un horario válido.
  String? _schedulePreview(DateTime today) {
    final statementDay = _dayOf(_statementDay);
    final dueDay = _dayOf(_dueDay);
    if (statementDay == null || dueDay == null) return null;
    try {
      validateCardSchedule(statementDay: statementDay, dueDay: dueDay);
    } on DomainException {
      return null;
    }
    final cycle = cycleForPurchase(today, statementDay: statementDay, dueDay: dueDay);
    return 'Próximo corte: ${formatDayMonth(cycle.closingDate)} · '
        'Pago hasta: ${formatDayMonth(cycle.dueDate)}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final preview = _isCard ? _schedulePreview(ref.watch(dayProvider)) : null;
    final noun = _isCard ? 'tarjeta' : 'cuenta';
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? 'Editar $noun'
              : _isCard
              ? 'Nueva tarjeta'
              : 'Nueva cuenta',
        ),
      ),
      bottomNavigationBar: _loading
          ? null
          : BottomActionBar(
              child: AppButton(
                label: _isEditing ? 'Guardar cambios' : 'Crear $noun',
                loading: _saving,
                onPressed: _save,
              ),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              controller: _scroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    for (final type in AccountType.values) Option(type, accountTypeLabel(type)),
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
                    for (final cur in {...accountCurrencies, _currency}) Option(cur, cur),
                  ],
                ),
                const SizedBox(height: Space.xl),
                Text(
                  !_isCard
                      ? 'SALDO INICIAL'
                      : _isEditing
                      ? 'DEUDA INICIAL'
                      : 'DEUDA ACTUAL',
                  style: t.label,
                ),
                const SizedBox(height: Space.xs),
                AmountInput(
                  controller: _balance,
                  currency: _currency,
                  label: _isCard ? 'Deuda actual' : 'Saldo inicial',
                  large: false,
                  errorText: _balanceError,
                  onChanged: (_) => setState(() => _balanceError = null),
                ),
                const SizedBox(height: Space.xs),
                Text(
                  !_isCard
                      ? 'Lo que tiene la cuenta hoy. Déjalo vacío si empieza en cero.'
                      : _isEditing
                      ? 'Lo que debías al empezar a usar la app. La deuda actual suma tus movimientos.'
                      : 'Lo que debes hoy en la tarjeta. Déjalo vacío si no debes nada.',
                  style: t.caption,
                  textAlign: TextAlign.center,
                ),
                if (_isCard) ...[
                  const SizedBox(height: Space.xl),
                  Text('LÍMITE DE CRÉDITO', style: t.label),
                  const SizedBox(height: Space.xs),
                  AmountInput(
                    controller: _limit,
                    currency: _currency,
                    label: 'Límite de crédito',
                    large: false,
                    errorText: _limitError,
                    onChanged: (_) => setState(() => _limitError = null),
                  ),
                  const SizedBox(height: Space.xl),
                  Text('CORTE Y PAGO', style: t.label),
                  const SizedBox(height: Space.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _dayField(_statementDay, 'Día de corte')),
                      const SizedBox(width: Space.md),
                      Expanded(child: _dayField(_dueDay, 'Día de pago')),
                    ],
                  ),
                  if (_daysError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: Space.sm),
                      child: Text(_daysError!, style: t.caption.copyWith(color: c.danger)),
                    ),
                  if (preview != null) ...[
                    const SizedBox(height: Space.md),
                    InfoNote(text: preview, icon: Icons.event_rounded),
                  ],
                  const SizedBox(height: Space.xl),
                  Text('PAGO MÍNIMO (OPCIONAL)', style: t.label),
                  const SizedBox(height: Space.sm),
                  TextField(
                    controller: _minPercent,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() => _minError = null),
                    decoration: InputDecoration(
                      labelText: 'Porcentaje de la deuda',
                      suffixText: '%',
                      errorText: _minError,
                      helperText: 'Sirve para estimar el mínimo antes de recibir el estado.',
                      helperMaxLines: 2,
                    ),
                  ),
                ],
                ],
              ),
            ),
    );
  }

  Widget _dayField(TextEditingController controller, String label) => TextField(
    controller: controller,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
    onChanged: (_) => setState(() => _daysError = null),
    decoration: InputDecoration(labelText: label, hintText: '1 a 31'),
  );
}
