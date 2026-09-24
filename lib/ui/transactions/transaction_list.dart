import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/format/dates.dart';
import '../../domain/clock.dart';
import '../common/describe_error.dart';
import 'transaction_tile.dart';

/// Cuántos movimientos se piden por página.
const transactionPageSize = 40;

extension on TransactionFilter {
  TransactionFilter withLimit(int limit) => TransactionFilter(
    accountId: accountId,
    categoryId: categoryId,
    contactId: contactId,
    debtId: debtId,
    statementId: statementId,
    tagId: tagId,
    type: type,
    from: from,
    to: to,
    limit: limit,
  );
}

/// Lista de movimientos agrupados por día, con paginación por desplazamiento.
///
/// [filter] no debe traer `limit` ni `offset`: la paginación es interna
/// (cada vez que se llega al final se pide una página más, y la lista se
/// mantiene reactiva ante altas, ediciones y borrados).
class TransactionList extends ConsumerStatefulWidget {
  const TransactionList({
    super.key,
    required this.filter,
    this.perspectiveAccountId,
    this.header,
    this.emptyMessage = 'Aún no hay movimientos.',
    this.pageSize = transactionPageSize,
  });

  final TransactionFilter filter;
  final String? perspectiveAccountId;

  /// Se muestra arriba, dentro del mismo desplazamiento.
  final Widget? header;
  final String emptyMessage;
  final int pageSize;

  @override
  ConsumerState<TransactionList> createState() => _TransactionListState();
}

class _TransactionListState extends ConsumerState<TransactionList> {
  late int _limit = widget.pageSize;
  List<Transaction>? _last;

  @override
  void didUpdateWidget(TransactionList old) {
    super.didUpdateWidget(old);
    if (old.filter != widget.filter) {
      _limit = widget.pageSize;
      _last = null;
    }
  }

  bool _onScroll(ScrollNotification n) {
    // Solo con el movimiento del usuario: otras notificaciones llegan durante
    // el layout, donde no se puede llamar a setState.
    if (n is! ScrollUpdateNotification && n is! ScrollEndNotification) return false;
    final hasMore = (_last?.length ?? 0) >= _limit;
    if (hasMore && n.metrics.extentAfter < 400) {
      setState(() => _limit += widget.pageSize);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(transactionsProvider(widget.filter.withLimit(_limit)));
    final accountsAsync = ref.watch(accountBalancesProvider(true));
    final categoriesAsync = ref.watch(categoriesProvider);
    final today = ref.watch(dayProvider);

    // Mientras llega la página más grande se sigue mostrando la anterior.
    if (async.hasValue) _last = async.requireValue;
    final data = _last;
    final failure = async.error ?? accountsAsync.error ?? categoriesAsync.error;
    if (data == null && failure != null) {
      return Center(child: Text(describeError(failure), textAlign: TextAlign.center));
    }
    if (data == null || !accountsAsync.hasValue || !categoriesAsync.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }

    final accounts = {for (final b in accountsAsync.requireValue) b.account.id: b.account};
    final categories = {for (final c in categoriesAsync.requireValue) c.id: c};
    final hasMore = data.length >= _limit;

    final rows = <Widget>[
      ?widget.header,
      if (data.isEmpty)
        Padding(
          padding: const EdgeInsets.all(32),
          child: Center(child: Text(widget.emptyMessage, textAlign: TextAlign.center)),
        ),
    ];
    DateTime? currentDay;
    for (final tx in data) {
      final day = dateOnly(tx.occurredAt);
      if (day != currentDay) {
        currentDay = day;
        rows.add(_DayHeader(formatDayHeader(day, today)));
      }
      rows.add(
        TransactionTile(
          transaction: tx,
          accounts: accounts,
          categories: categories,
          perspectiveAccountId: widget.perspectiveAccountId,
          onTap: () => context.push(Routes.transactionEdit(tx.id)),
        ),
      );
    }
    if (hasMore) {
      rows.add(
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: rows.length,
        itemBuilder: (_, i) => rows[i],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
}
