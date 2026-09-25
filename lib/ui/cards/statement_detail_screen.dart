import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../domain/credit_card/statement_status.dart';
import '../common/async_body.dart';
import '../common/confirm_dialog.dart';
import '../common/describe_error.dart';
import '../design/amount_row.dart';
import '../design/amount_text.dart';
import '../design/app_button.dart';
import '../design/app_card.dart';
import '../design/bottom_action_bar.dart';
import '../design/info_note.dart';
import '../design/status_badge.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../transactions/transaction_list.dart';
import 'card_labels.dart';

/// Detalle de un estado de cuenta: montos oficiales, lo pagado, el desglose del
/// período y los pagos vinculados.
class StatementDetailScreen extends ConsumerWidget {
  const StatementDetailScreen({super.key, required this.cardId, required this.statementId});

  final String cardId;
  final String statementId;

  Future<void> _setArchived(BuildContext context, WidgetRef ref, bool archived) async {
    if (archived) {
      final ok = await confirmAction(
        context,
        title: 'Archivar estado de cuenta',
        message:
            'Dejará de contar como pendiente y de sugerirse para nuevos pagos. '
            'Puedes restaurarlo cuando quieras.',
        confirmLabel: 'Archivar',
      );
      if (!ok || !context.mounted) return;
    }
    try {
      await ref.read(creditCardRepositoryProvider).setStatementArchived(statementId, archived);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statements = ref.watch(cardStatementsProvider((cardId: cardId, includeArchived: true)));
    final currency = ref.watch(cardOverviewProvider(cardId)).value?.account.currency ?? 'GTQ';
    final view = statements.value?.where((v) => v.statement.id == statementId).firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estado de cuenta'),
        actions: [
          if (view != null) ...[
            IconButton(
              tooltip: 'Editar estado de cuenta',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push(Routes.statementEdit(cardId, statementId)),
            ),
            PopupMenuButton<void>(
              tooltip: 'Más opciones',
              itemBuilder: (_) => [
                PopupMenuItem<void>(
                  onTap: () => _setArchived(context, ref, !view.statement.isArchived),
                  child: Text(view.statement.isArchived ? 'Restaurar estado' : 'Archivar estado'),
                ),
              ],
            ),
          ],
        ],
      ),
      bottomNavigationBar:
          view == null || view.statement.isArchived || view.status == StatementStatus.paid
          ? null
          : BottomActionBar(
              child: AppButton(
                label: 'Pagar este estado',
                icon: Icons.payments_outlined,
                onPressed: () => context.push(
                  Routes.transactionNewFor(
                    type: TransactionType.transfer,
                    destinationId: cardId,
                    statementId: statementId,
                    amountMinor: (view.statement.statementBalanceMinor - view.paidMinor).clamp(
                      0,
                      1 << 62,
                    ),
                  ),
                ),
              ),
            ),
      body: AsyncBody(
        value: statements,
        data: (_) {
          if (view == null) return const Center(child: Text('Este estado de cuenta ya no existe.'));
          return TransactionList(
            filter: TransactionFilter(statementId: statementId),
            emptyMessage: 'Aún no hay pagos vinculados a este estado.',
            emptyHint: 'Los pagos que le vincules aparecerán aquí.',
            header: _Header(view: view, currency: currency),
          );
        },
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.view, required this.currency});

  final StatementView view;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.text;
    final s = view.statement;
    final today = ref.watch(dayProvider);
    final m = view.movements;
    final pending = (s.statementBalanceMinor - view.paidMinor).clamp(0, 1 << 62);
    final toDue = daysBetween(today, s.dueDate);
    final diff = view.differenceMinor;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Corte ${formatDate(s.closingDate)}', style: t.heading)),
              StatusBadge(
                label: statementStatusLabel(view.status),
                tone: statementStatusTone(context, view.status),
              ),
            ],
          ),
          const SizedBox(height: Space.xs),
          Text(
            'Período ${formatDayMonth(s.periodStart)} – ${formatDayMonth(s.closingDate)}',
            style: t.caption,
          ),
          if (s.isArchived) ...[
            const SizedBox(height: Space.sm),
            const Chip(
              label: Text('Archivado'),
              visualDensity: VisualDensity.compact,
              avatar: Icon(Icons.archive_outlined, size: 16),
            ),
          ],
          const SizedBox(height: Space.lg),
          Text('Saldo oficial', style: t.caption),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AmountText(s.statementBalanceMinor, currency, size: AmountSize.xl),
          ),
          const SizedBox(height: Space.lg),
          AppCard(
            child: Column(
              children: [
                AmountRow(label: 'Pago mínimo', minor: s.minimumPaymentMinor, currency: currency),
                AmountRow(
                  label: 'Pagado',
                  minor: view.paidMinor,
                  currency: currency,
                  color: view.paidMinor > 0 ? c.income : null,
                ),
                AmountRow(label: 'Pendiente', minor: pending, currency: currency, strong: true),
                const Divider(height: Space.xl),
                Row(
                  children: [
                    Expanded(child: Text('Pago hasta ${formatDate(s.dueDate)}', style: t.body)),
                    Text(
                      view.status == StatementStatus.paid
                          ? '—'
                          : view.status == StatementStatus.overdue
                          ? 'Vencido'
                          : daysLabel(toDue),
                      style: t.bodyStrong.copyWith(
                        color: view.status == StatementStatus.overdue ? c.expense : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.lg),
          if (diff != 0)
            InfoNote(
              icon: Icons.warning_amber_rounded,
              text:
                  'La app estimaba ${formatMoney(view.estimatedBalanceMinor, currency)}. '
                  'El banco reporta ${formatSignedMoney(diff, currency)} respecto a eso. '
                  'Revisa si falta algún movimiento.',
            )
          else
            InfoNote(
              icon: Icons.check_circle_outline_rounded,
              text: 'El estimado de la app coincide con el estado del banco.',
            ),
          Padding(
            padding: const EdgeInsets.only(top: Space.xl, bottom: Space.sm),
            child: Text('DESGLOSE DEL PERÍODO', style: t.label),
          ),
          AppCard(
            child: Column(
              children: [
                if (m.openingDebtMinor != 0)
                  AmountRow(
                    label: 'Deuda arrastrada',
                    minor: m.openingDebtMinor,
                    currency: currency,
                  ),
                AmountRow(label: 'Compras', minor: m.purchasesMinor, currency: currency),
                if (m.interestMinor != 0)
                  AmountRow(
                    label: 'Intereses y cargos',
                    minor: m.interestMinor,
                    currency: currency,
                  ),
                if (m.cashAdvancesMinor != 0)
                  AmountRow(
                    label: 'Avances de efectivo',
                    minor: m.cashAdvancesMinor,
                    currency: currency,
                  ),
                if (m.refundsMinor != 0)
                  AmountRow(
                    label: 'Devoluciones',
                    minor: -m.refundsMinor,
                    currency: currency,
                    color: c.income,
                  ),
                if (m.otherCreditsMinor != 0)
                  AmountRow(
                    label: 'Otros créditos',
                    minor: -m.otherCreditsMinor,
                    currency: currency,
                    color: c.income,
                  ),
                if (m.paymentsMinor != 0)
                  AmountRow(
                    label: 'Pagos del período',
                    minor: -m.paymentsMinor,
                    currency: currency,
                    color: c.income,
                  ),
                const Divider(height: Space.xl),
                AmountRow(
                  label: 'Estimado por la app',
                  minor: view.estimatedBalanceMinor,
                  currency: currency,
                  strong: true,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: Space.xl, bottom: Space.sm),
            child: Text('PAGOS VINCULADOS', style: t.label),
          ),
        ],
      ),
    );
  }
}
