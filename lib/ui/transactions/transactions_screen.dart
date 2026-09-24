import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../accounts/account_labels.dart';
import '../accounts/no_accounts_invite.dart';
import '../common/async_body.dart';
import '../design/tab_app_bar.dart';
import '../design/tokens.dart';
import 'transaction_filter_params.dart';
import 'transaction_filter_sheet.dart';
import 'transaction_labels.dart';
import 'transaction_list.dart';

/// Pestaña Movimientos: todos los movimientos, con filtros que viven en la
/// URL (`/movimientos?cuenta=…`).
class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key, required this.params});

  final TransactionFilterParams params;

  void _apply(BuildContext context, TransactionFilterParams next) {
    context.go(
      Uri(
        path: Routes.transactions,
        queryParameters: next.toQuery().isEmpty ? null : next.toQuery(),
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountBalancesProvider(true));
    return Scaffold(
      appBar: tabAppBar(
        context,
        'Movimientos',
        actions: [
          IconButton(
            tooltip: 'Filtrar',
            onPressed: () async {
              final next = await showTransactionFilterSheet(context, params);
              if (next != null && context.mounted) _apply(context, next);
            },
            icon: Badge(
              isLabelVisible: params.activeCount > 0,
              backgroundColor: context.colors.accent,
              textColor: context.colors.onAccent,
              label: Text('${params.activeCount}'),
              child: const Icon(Icons.tune_rounded),
            ),
          ),
        ],
      ),
      body: AsyncBody(
        value: accountsAsync,
        data: (balances) {
          if (!balances.any((b) => isPlainAccount(b.account))) return const NoAccountsInvite();
          return Column(
            children: [
              if (!params.isEmpty)
                _ActiveFilters(params: params, onChanged: (next) => _apply(context, next)),
              Expanded(
                child: TransactionList(
                  filter: params.toFilter(),
                  perspectiveAccountId: params.accountId,
                  emptyMessage: params.isEmpty
                      ? 'Aún no hay movimientos'
                      : 'Ningún movimiento coincide con los filtros.',
                  emptyHint: params.isEmpty
                      ? 'Registra el primero con el botón + de la barra inferior.'
                      : 'Prueba quitando alguno.',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Un chip por filtro activo; tocar su cruz lo quita.
class _ActiveFilters extends ConsumerWidget {
  const _ActiveFilters({required this.params, required this.onChanged});

  final TransactionFilterParams params;
  final ValueChanged<TransactionFilterParams> onChanged;

  TransactionFilterParams _copy({
    bool account = true,
    bool type = true,
    bool category = true,
    bool tag = true,
    bool range = true,
  }) => TransactionFilterParams(
    accountId: account ? params.accountId : null,
    type: type ? params.type : null,
    categoryId: category ? params.categoryId : null,
    tagId: tag ? params.tagId : null,
    from: range ? params.from : null,
    to: range ? params.to : null,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = {
      for (final b in ref.watch(accountBalancesProvider(true)).value ?? const <AccountBalance>[])
        b.account.id: b.account,
    };
    final categories = {
      for (final c in ref.watch(categoriesProvider).value ?? const <Category>[]) c.id: c,
    };
    final tags = {for (final t in ref.watch(tagsProvider).value ?? const <Tag>[]) t.id: t};

    Widget chip(String label, VoidCallback onDeleted) =>
        InputChip(label: Text(label), onDeleted: onDeleted);

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          if (params.accountId != null)
            chip(
              accounts[params.accountId]?.name ?? 'Cuenta',
              () => onChanged(_copy(account: false)),
            ),
          if (params.type != null)
            chip(transactionTypeLabel(params.type!), () => onChanged(_copy(type: false))),
          if (params.categoryId != null)
            chip(
              categories[params.categoryId] == null
                  ? 'Categoría'
                  : categoryLabel(categories[params.categoryId]!, categories),
              () => onChanged(_copy(category: false)),
            ),
          if (params.tagId != null)
            chip(tags[params.tagId]?.name ?? 'Etiqueta', () => onChanged(_copy(tag: false))),
          if (params.rangeLabel != null)
            chip(params.rangeLabel!, () => onChanged(_copy(range: false))),
        ].expand((w) => [w, const SizedBox(width: 8)]).toList(),
      ),
    );
  }
}
