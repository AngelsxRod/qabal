import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../accounts/account_labels.dart';
import 'transaction_filter_params.dart';
import 'transaction_labels.dart';

/// Hoja inferior para elegir los filtros. Devuelve los nuevos filtros al
/// aplicar (vacíos si se limpian) o `null` si se descarta.
Future<TransactionFilterParams?> showTransactionFilterSheet(
  BuildContext context,
  TransactionFilterParams initial,
) => showModalBottomSheet<TransactionFilterParams>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _FilterSheet(initial: initial),
);

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({required this.initial});

  final TransactionFilterParams initial;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late String? _accountId = widget.initial.accountId;
  late TransactionType? _type = widget.initial.type;
  late String? _categoryId = widget.initial.categoryId;
  late String? _tagId = widget.initial.tagId;
  late DateTime? _from = widget.initial.from;
  late DateTime? _to = widget.initial.to;

  TransactionFilterParams get _params => TransactionFilterParams(
    accountId: _accountId,
    type: _type,
    categoryId: _categoryId,
    tagId: _tagId,
    from: _from,
    to: _to,
  );

  Future<void> _pickRange() async {
    final today = ref.read(dayProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year + 1, today.month, today.day),
      initialDateRange: _from != null && _to != null
          ? DateTimeRange(start: _from!, end: _to!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _from = picked.start;
        _to = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = (ref.watch(accountBalancesProvider(true)).value ?? const [])
        .map((b) => b.account)
        .where(isPlainAccount)
        .toList();
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final categoriesById = {for (final c in categories) c.id: c};
    final sortedCategories = [...categories]
      ..sort(
        (a, b) => categoryLabel(
          a,
          categoriesById,
        ).toLowerCase().compareTo(categoryLabel(b, categoriesById).toLowerCase()),
      );
    final tags = ref.watch(tagsProvider).value ?? const <Tag>[];
    final rangeLabel = _params.rangeLabel;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Filtrar movimientos', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: accounts.any((a) => a.id == _accountId) ? _accountId : null,
              decoration: const InputDecoration(labelText: 'Cuenta'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todas')),
                for (final a in accounts)
                  DropdownMenuItem(
                    value: a.id,
                    child: Text(a.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _accountId = v),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TransactionType?>(
              isExpanded: true,
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos')),
                for (final t in TransactionType.values)
                  DropdownMenuItem(value: t, child: Text(transactionTypeLabel(t))),
              ],
              onChanged: (v) => setState(() => _type = v),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: categoriesById.containsKey(_categoryId) ? _categoryId : null,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todas')),
                for (final c in sortedCategories)
                  DropdownMenuItem(
                    value: c.id,
                    child: Text(categoryLabel(c, categoriesById), overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                isExpanded: true,
                initialValue: tags.any((t) => t.id == _tagId) ? _tagId : null,
                decoration: const InputDecoration(labelText: 'Etiqueta'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todas')),
                  for (final t in tags)
                    DropdownMenuItem(
                      value: t.id,
                      child: Text(t.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => _tagId = v),
              ),
            ],
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickRange,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Fechas',
                  suffixIcon: rangeLabel == null
                      ? const Icon(Icons.date_range_outlined)
                      : IconButton(
                          tooltip: 'Quitar fechas',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() {
                            _from = null;
                            _to = null;
                          }),
                        ),
                ),
                child: Text(rangeLabel ?? 'Todas'),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(const TransactionFilterParams()),
                  child: const Text('Limpiar'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(_params),
                  child: const Text('Aplicar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
