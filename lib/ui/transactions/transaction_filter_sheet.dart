import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../accounts/account_labels.dart';
import '../design/account_chips.dart';
import '../design/app_button.dart';
import '../design/category_avatar.dart';
import '../design/category_picker.dart';
import '../design/category_style.dart';
import '../design/option_chips.dart';
import '../design/picker_row.dart';
import '../design/tokens.dart';
import '../design/type_switcher.dart';
import '../design/typography.dart';
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
  useSafeArea: true,
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
    final c = context.colors;
    final t = context.text;
    final brightness = Theme.of(context).brightness;
    final accounts = (ref.watch(accountBalancesProvider(true)).value ?? const [])
        .map((b) => b.account)
        .where(isPlainAccount)
        .toList();
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final categoriesById = {for (final x in categories) x.id: x};
    final tags = (ref.watch(tagsProvider).value ?? const <Tag>[])
        .where((x) => !x.isArchived || x.id == _tagId)
        .toList();
    final selectedCategory = categoriesById[_categoryId];
    final style = categoryStyleFor(selectedCategory, brightness);
    // Con un tipo elegido solo se ofrecen las categorías de ese tipo.
    final offered =
        categories
            .where(
              (x) =>
                  !x.isArchived &&
                  switch (_type) {
                    TransactionType.income => x.kind == CategoryKind.income,
                    TransactionType.expense => x.kind == CategoryKind.expense,
                    TransactionType.transfer => false,
                    null => true,
                  },
            )
            .toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final rangeLabel = _params.rangeLabel;

    Widget label(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, Space.sm),
      child: Text(text, style: t.label),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: Text('Filtrar movimientos', style: t.title),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: Space.lg),
            children: [
              label('TIPO'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: TypeSwitcher<TransactionType?>(
                  value: _type,
                  options: const [
                    (null, 'Todos'),
                    (TransactionType.expense, 'Gasto'),
                    (TransactionType.income, 'Ingreso'),
                    (TransactionType.transfer, 'Transf.'),
                  ],
                  onChanged: (v) => setState(() {
                    _type = v;
                    // Una categoría de otro tipo ya no aplica.
                    final cat = categoriesById[_categoryId];
                    if (cat != null && v != null && v != TransactionType.transfer) {
                      final expected = v == TransactionType.income
                          ? CategoryKind.income
                          : CategoryKind.expense;
                      if (cat.kind != expected) _categoryId = null;
                    }
                  }),
                ),
              ),
              label('CUENTA'),
              AccountChips(
                accounts: accounts,
                selectedId: _accountId,
                allLabel: 'Todas',
                onSelected: (id) => setState(() => _accountId = id),
              ),
              label('CATEGORÍA Y FECHAS'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(Radii.lg),
                    border: Border.all(color: c.border),
                  ),
                  child: Column(
                    children: [
                      PickerRow(
                        label: 'Categoría',
                        value: selectedCategory == null
                            ? 'Todas'
                            : categoryLabel(selectedCategory, categoriesById),
                        placeholder: selectedCategory == null,
                        leading: CategoryAvatar(icon: style.icon, color: style.color, size: 36),
                        onTap: () async {
                          final pick = await showCategoryPicker(
                            context,
                            categories: offered,
                            selectedId: _categoryId,
                            noneLabel: 'Todas',
                          );
                          if (pick != null) setState(() => _categoryId = pick.id);
                        },
                      ),
                      Divider(color: c.border),
                      PickerRow(
                        label: 'Fechas',
                        value: rangeLabel ?? 'Todas',
                        placeholder: rangeLabel == null,
                        leading: SizedBox(
                          width: 36,
                          height: 36,
                          child: Icon(Icons.date_range_rounded, color: c.textSecondary, size: 22),
                        ),
                        trailing: rangeLabel == null
                            ? null
                            : IconButton(
                                tooltip: 'Quitar fechas',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () => setState(() {
                                  _from = null;
                                  _to = null;
                                }),
                              ),
                        onTap: _pickRange,
                      ),
                    ],
                  ),
                ),
              ),
              if (tags.isNotEmpty) ...[
                label('ETIQUETA'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  child: OptionChips<String?>(
                    value: _tagId,
                    onChanged: (v) => setState(() => _tagId = v),
                    options: [
                      const Option<String?>(null, 'Todas'),
                      for (final tag in tags) Option<String?>(tag.id, tag.name),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            Space.gutter,
            Space.sm,
            Space.gutter,
            Space.lg + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Row(
            children: [
              AppButton(
                label: 'Limpiar',
                kind: AppButtonKind.text,
                onPressed: () => Navigator.of(context).pop(const TransactionFilterParams()),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: AppButton(
                  label: 'Aplicar',
                  onPressed: () => Navigator.of(context).pop(_params),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
