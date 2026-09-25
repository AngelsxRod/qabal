import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../data/database/seed.dart';
import '../accounts/account_archive.dart';
import '../common/async_body.dart';
import '../design/amount_row.dart';
import '../design/amount_text.dart';
import '../design/app_button.dart';
import '../design/app_card.dart';
import '../design/quick_action.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/usage_bar.dart';
import '../transactions/transaction_list.dart';
import 'card_labels.dart';
import 'statement_row.dart';

/// Detalle de una tarjeta de crédito: cuánto debo, crédito disponible, ciclo en
/// curso, estados de cuenta y movimientos.
class CardDetailScreen extends ConsumerWidget {
  const CardDetailScreen({super.key, required this.cardId});

  final String cardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(cardOverviewProvider(cardId));
    final account = overview.value?.account;
    return Scaffold(
      appBar: AppBar(
        title: Text(account?.name ?? 'Tarjeta'),
        actions: [
          if (account != null) ...[
            IconButton(
              tooltip: 'Editar tarjeta',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push(Routes.accountEdit(cardId)),
            ),
            PopupMenuButton<void>(
              tooltip: 'Más opciones',
              itemBuilder: (_) => [
                PopupMenuItem<void>(
                  onTap: () => setAccountArchived(context, ref, cardId, !account.isArchived),
                  child: Text(account.isArchived ? 'Restaurar tarjeta' : 'Archivar tarjeta'),
                ),
              ],
            ),
          ],
        ],
      ),
      body: AsyncBody(
        value: overview,
        data: (o) => TransactionList(
          filter: TransactionFilter(accountId: cardId),
          perspectiveAccountId: cardId,
          emptyMessage: 'Esta tarjeta aún no tiene movimientos.',
          emptyHint: 'Cuando registres una compra, aparecerá aquí.',
          header: _Header(overview: o),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.overview});

  final CardOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = overview.account;
    final cur = a.currency;
    final c = context.colors;
    final t = context.text;
    final cycle = overview.summary;
    final today = ref.watch(dayProvider);
    final limit = overview.settings.creditLimitMinor;
    final statements = ref.watch(
      cardStatementsProvider((cardId: a.id, includeArchived: false)),
    );

    void open({
      required TransactionType type,
      String? categoryId,
      String? destinationId,
      String? sourceId,
    }) => context.push(
      Routes.transactionNewFor(
        accountId: sourceId ?? (destinationId == null ? a.id : null),
        type: type,
        destinationId: destinationId,
        categoryId: categoryId,
      ),
    );

    final m = cycle.movements;
    final toClosing = daysBetween(today, cycle.cycle.closingDate);
    final toDue = daysBetween(today, cycle.cycle.dueDate);

    Widget section(String title) => Padding(
      padding: const EdgeInsets.only(top: Space.xl, bottom: Space.sm),
      child: Text(title, style: t.label),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tarjeta de crédito · $cur', style: t.caption),
          const SizedBox(height: Space.xs),
          Text('Debes', style: t.caption),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AmountText(
              overview.owedMinor,
              cur,
              size: AmountSize.xl,
              color: overview.owedMinor > 0 ? c.expense : null,
            ),
          ),
          const SizedBox(height: Space.md),
          UsageBar(fraction: limit == 0 ? 0 : overview.debtMinor / limit),
          const SizedBox(height: Space.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Disponible ${formatMoney(overview.availableCreditMinor, cur)}',
                  style: t.caption,
                ),
              ),
              Text('Límite ${formatMoney(limit, cur)}', style: t.caption),
            ],
          ),
          if (a.isArchived) ...[
            const SizedBox(height: Space.md),
            const Chip(
              label: Text('Archivada'),
              visualDensity: VisualDensity.compact,
              avatar: Icon(Icons.archive_outlined, size: 16),
            ),
          ] else ...[
            const SizedBox(height: Space.lg),
            QuickActions(
              children: [
                QuickAction(
                  icon: Icons.shopping_bag_outlined,
                  label: 'Compra',
                  onTap: () => open(type: TransactionType.expense),
                ),
                QuickAction(
                  icon: Icons.payments_outlined,
                  label: 'Pagar',
                  onTap: () => open(type: TransactionType.transfer, destinationId: a.id),
                ),
                QuickAction(
                  icon: Icons.undo_rounded,
                  label: 'Devolución',
                  onTap: () => open(type: TransactionType.income, categoryId: kRefundsCategoryId),
                ),
              ],
            ),
            const SizedBox(height: Space.sm),
            QuickActions(
              children: [
                QuickAction(
                  icon: Icons.percent_rounded,
                  label: 'Intereses',
                  onTap: () =>
                      open(type: TransactionType.expense, categoryId: kInterestFeesCategoryId),
                ),
                QuickAction(
                  icon: Icons.receipt_long_outlined,
                  label: 'Estado',
                  onTap: () => context.push(Routes.statementNew(a.id)),
                ),
                QuickAction(
                  icon: Icons.edit_outlined,
                  label: 'Editar',
                  onTap: () => context.push(Routes.accountEdit(a.id)),
                ),
              ],
            ),
          ],
          section('CICLO ACTUAL'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${formatDayMonth(cycle.cycle.periodStart)} – '
                  '${formatDate(cycle.cycle.closingDate)}',
                  style: t.bodyStrong,
                ),
                const SizedBox(height: Space.sm),
                _KeyValue(
                  'Corte ${formatDayMonth(cycle.cycle.closingDate)}',
                  daysLabel(toClosing),
                ),
                _KeyValue('Pago hasta ${formatDayMonth(cycle.cycle.dueDate)}', daysLabel(toDue)),
                const Divider(height: Space.xl),
                if (m.openingDebtMinor != 0)
                  AmountRow(label: 'Deuda arrastrada', minor: m.openingDebtMinor, currency: cur),
                AmountRow(label: 'Compras', minor: m.purchasesMinor, currency: cur),
                if (m.interestMinor != 0)
                  AmountRow(label: 'Intereses y cargos', minor: m.interestMinor, currency: cur),
                if (m.cashAdvancesMinor != 0)
                  AmountRow(label: 'Avances de efectivo', minor: m.cashAdvancesMinor, currency: cur),
                if (m.refundsMinor != 0)
                  AmountRow(
                    label: 'Devoluciones',
                    minor: -m.refundsMinor,
                    currency: cur,
                    color: c.income,
                  ),
                if (m.otherCreditsMinor != 0)
                  AmountRow(
                    label: 'Otros créditos',
                    minor: -m.otherCreditsMinor,
                    currency: cur,
                    color: c.income,
                  ),
                if (m.paymentsMinor != 0)
                  AmountRow(
                    label: 'Pagos',
                    minor: -m.paymentsMinor,
                    currency: cur,
                    color: c.income,
                  ),
                const Divider(height: Space.xl),
                AmountRow(
                  label: 'Estimado al corte',
                  minor: cycle.estimatedClosingMinor,
                  currency: cur,
                  strong: true,
                ),
                if (cycle.estimatedMinimumMinor != null)
                  AmountRow(
                    label: 'Mínimo estimado',
                    minor: cycle.estimatedMinimumMinor!,
                    currency: cur,
                  ),
                if (cycle.previousStatementPendingMinor != null)
                  AmountRow(
                    label: 'Pendiente del estado anterior',
                    minor: cycle.previousStatementPendingMinor!,
                    currency: cur,
                    note: 'Lo que falta de tu último estado de cuenta',
                  ),
              ],
            ),
          ),
          section('ESTADOS DE CUENTA'),
          statements.when(
            data: (list) => list.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm),
                    child: Text(
                      'Aún no registras ningún estado de cuenta.',
                      style: t.caption,
                    ),
                  )
                : AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < list.length; i++) ...[
                          if (i > 0) Divider(color: c.border),
                          StatementRow(
                            view: list[i],
                            currency: cur,
                            onTap: () =>
                                context.push(Routes.statementDetail(a.id, list[i].statement.id)),
                          ),
                        ],
                      ],
                    ),
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const SizedBox.shrink(),
          ),
          if (!a.isArchived) ...[
            const SizedBox(height: Space.md),
            AppButton(
              label: 'Registrar estado de cuenta',
              kind: AppButtonKind.secondary,
              icon: Icons.add_rounded,
              onPressed: () => context.push(Routes.statementNew(a.id)),
            ),
          ],
          section('MOVIMIENTOS'),
        ],
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: t.body)),
          Text(value, style: t.bodyStrong),
        ],
      ),
    );
  }
}
