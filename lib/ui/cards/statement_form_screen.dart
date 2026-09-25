import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/format/money_input.dart';
import '../../domain/clock.dart';
import '../../domain/credit_card/card_cycle.dart';
import '../../domain/errors.dart';
import '../common/describe_error.dart';
import '../design/amount_input.dart';
import '../design/app_button.dart';
import '../design/app_card.dart';
import '../design/bottom_action_bar.dart';
import '../design/info_note.dart';
import '../design/picker_row.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'card_labels.dart';

/// Registra el estado de cuenta de una tarjeta con los valores del banco o, con
/// [statementId], corrige sus montos y su fecha de pago (el corte no cambia).
class StatementFormScreen extends ConsumerStatefulWidget {
  const StatementFormScreen({super.key, required this.cardId, this.statementId});

  final String cardId;
  final String? statementId;

  @override
  ConsumerState<StatementFormScreen> createState() => _StatementFormScreenState();
}

class _StatementFormScreenState extends ConsumerState<StatementFormScreen> {
  final _balance = TextEditingController();
  final _minimum = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  late String _currency;
  late CreditCardDetail _settings;
  late DateTime _closing;
  DateTime? _due; // fecha elegida; null = la que sale del horario de la tarjeta
  int? _estimated; // deuda al corte según la app
  String? _closingError;
  String? _balanceError;
  String? _minimumError;
  String? _generalError;

  bool get _isEditing => widget.statementId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _balance.dispose();
    _minimum.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final accounts = ref.read(accountRepositoryProvider);
    final cards = ref.read(creditCardRepositoryProvider);
    final account = await accounts.get(widget.cardId);
    final settings = await accounts.cardSettings(widget.cardId);
    if (!mounted) return;
    if (account == null || settings == null) {
      context.pop();
      return;
    }
    final existing = await cards.statements(widget.cardId, includeArchived: true);
    if (!mounted) return;
    _currency = account.currency;
    _settings = settings;
    if (_isEditing) {
      final s = existing.where((v) => v.statement.id == widget.statementId).firstOrNull;
      if (s == null) {
        context.pop();
        return;
      }
      _closing = s.statement.closingDate;
      _due = s.statement.dueDate;
      _balance.text = formatGrouped(s.statement.statementBalanceMinor);
      _minimum.text = formatGrouped(s.statement.minimumPaymentMinor);
    } else {
      _closing = defaultStatementClosing(ref.read(dayProvider), settings, {
        for (final v in existing) dateOnly(v.statement.closingDate),
      });
    }
    await _refreshEstimate();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refreshEstimate() async {
    final estimate = await ref
        .read(creditCardRepositoryProvider)
        .estimatedBalanceAt(widget.cardId, _closing);
    if (mounted) setState(() => _estimated = estimate);
  }

  DateTime get _derivedDue => cycleClosingOn(
    _closing.year,
    _closing.month,
    statementDay: _settings.statementDay,
    dueDay: _settings.dueDay,
  ).dueDate;

  Future<void> _pickClosing() async {
    FocusScope.of(context).unfocus();
    final today = ref.read(dayProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: _closing,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year + 1, today.month, today.day),
    );
    if (picked == null) return;
    setState(() {
      _closing = dateOnly(picked);
      _closingError = null;
    });
    await _refreshEstimate();
  }

  Future<void> _pickDue() async {
    FocusScope.of(context).unfocus();
    final initial = _due ?? _derivedDue;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(initial.year + 2, initial.month, initial.day),
    );
    if (picked != null) setState(() => _due = dateOnly(picked));
  }

  Future<void> _save() async {
    setState(() {
      _closingError = _balanceError = _minimumError = _generalError = null;
    });
    final balance = parseInputMinor(_balance.text.trim());
    final minimum = parseInputMinor(_minimum.text.trim());
    String? balanceError;
    String? minimumError;
    if (_balance.text.trim().isEmpty) {
      balanceError = 'Escribe el saldo del estado de cuenta';
    } else if (balance == null) {
      balanceError = invalidAmountMessage;
    }
    if (_minimum.text.trim().isEmpty) {
      minimumError = 'Escribe el pago mínimo';
    } else if (minimum == null) {
      minimumError = invalidAmountMessage;
    } else if (balance != null && minimum > balance) {
      minimumError = 'El pago mínimo no puede superar el saldo';
    }
    if (balanceError != null || minimumError != null) {
      setState(() {
        _balanceError = balanceError;
        _minimumError = minimumError;
      });
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(creditCardRepositoryProvider);
      if (_isEditing) {
        await repo.updateStatement(
          widget.statementId!,
          balanceMinor: balance,
          minimumMinor: minimum,
          dueDate: _due,
        );
      } else {
        await repo.registerStatement(
          StatementInput(
            accountId: widget.cardId,
            closingDate: _closing,
            statementBalanceMinor: balance!,
            minimumPaymentMinor: minimum!,
            dueDate: _due,
          ),
        );
      }
      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        final message = describeError(e);
        if (e is DuplicateStatementException || e is StatementOverlapException) {
          _closingError = message;
        } else {
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
    final official = parseInputMinor(_balance.text.trim());
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar estado de cuenta' : 'Nuevo estado de cuenta'),
      ),
      bottomNavigationBar: _loading
          ? null
          : BottomActionBar(
              child: AppButton(
                label: _isEditing ? 'Guardar cambios' : 'Registrar estado',
                loading: _saving,
                onPressed: _save,
              ),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.xl),
              children: [
                if (_generalError != null) ...[
                  Text(_generalError!, style: t.caption.copyWith(color: c.danger)),
                  const SizedBox(height: Space.md),
                ],
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      PickerRow(
                        label: 'Fecha de corte',
                        value: formatDate(_closing),
                        errorText: _closingError,
                        leading: Icon(Icons.event_rounded, color: c.textSecondary),
                        onTap: _pickClosing,
                        trailing: _isEditing ? const SizedBox.shrink() : null,
                      ),
                      Divider(color: c.border),
                      PickerRow(
                        label: 'Fecha de pago (opcional)',
                        value: formatDate(_due ?? _derivedDue),
                        leading: Icon(Icons.event_available_rounded, color: c.textSecondary),
                        onTap: _pickDue,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.xs),
                Text(
                  _due == null
                      ? 'La fecha de pago sale del día de pago de la tarjeta.'
                      : 'Fecha de pago elegida por ti.',
                  style: t.caption,
                ),
                const SizedBox(height: Space.xl),
                Text('SALDO DEL ESTADO DE CUENTA', style: t.label),
                const SizedBox(height: Space.xs),
                AmountInput(
                  controller: _balance,
                  currency: _currency,
                  label: 'Saldo del estado de cuenta',
                  large: false,
                  autofocus: !_isEditing,
                  errorText: _balanceError,
                  onChanged: (_) => setState(() => _balanceError = null),
                ),
                const SizedBox(height: Space.xl),
                Text('PAGO MÍNIMO', style: t.label),
                const SizedBox(height: Space.xs),
                AmountInput(
                  controller: _minimum,
                  currency: _currency,
                  label: 'Pago mínimo',
                  large: false,
                  errorText: _minimumError,
                  onChanged: (_) => setState(() => _minimumError = null),
                ),
                if (_estimated != null && official != null) ...[
                  const SizedBox(height: Space.xl),
                  InfoNote(
                    icon: Icons.balance_rounded,
                    text:
                        'La app estima ${formatMoney(_estimated!, _currency)} · '
                        'El banco dice ${formatMoney(official, _currency)} · '
                        'Diferencia ${formatSignedMoney(official - _estimated!, _currency)}',
                  ),
                ],
              ],
            ),
    );
  }
}
