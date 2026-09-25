import 'package:flutter/material.dart';

import '../../data/database/app_database.dart';
import 'account_chips.dart';
import 'amount_input.dart';
import 'amount_text.dart';
import 'app_bottom_bar.dart';
import 'app_button.dart';
import 'app_card.dart';
import 'app_theme.dart';
import 'category_avatar.dart';
import 'category_picker.dart';
import 'category_style.dart';
import 'day_header.dart';
import 'amount_row.dart';
import 'empty_state.dart';
import 'info_note.dart';
import 'list_row.dart';
import 'month_selector.dart';
import 'picker_row.dart';
import 'status_badge.dart';
import 'style_choosers.dart';
import 'tokens.dart';
import 'transaction_row.dart';
import 'type_switcher.dart';
import 'typography.dart';
import 'usage_bar.dart';

/// Galería de componentes para revisar el diseño en claro y oscuro. Solo se
/// enlaza desde "Más" en builds de depuración.
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  bool _dark = false;
  final _amount = TextEditingController(text: '1234.50');
  String _type = 'expense';
  String _account = 'a1';
  String? _category = 'default:food';
  int _tab = 1;
  DateTime _month = DateTime(2026, 9);
  String _icon = 'restaurant';
  Color _color = categoryColorChoices[0];

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  static final _now = DateTime(2026, 9, 24);
  static Account _acc(String id, String name, AccountType type) => Account(
    id: id,
    name: name,
    type: type,
    currency: 'GTQ',
    initialBalanceMinor: 0,
    isArchived: false,
    createdAt: _now,
    updatedAt: _now,
  );

  static Category _cat(String id, String name, String icon, CategoryKind kind) => Category(
    id: id,
    name: name,
    kind: kind,
    icon: icon,
    isArchived: false,
    createdAt: _now,
    updatedAt: _now,
  );

  static final _accounts = [
    _acc('a1', 'Efectivo', AccountType.cash),
    _acc('a2', 'Banrural', AccountType.bank),
    _acc('a3', 'Ahorros', AccountType.savings),
    _acc('a4', 'Dólares', AccountType.other),
    _acc('a5', 'Viajes', AccountType.savings),
  ];

  static final _categories = [
    _cat('default:food', 'Comida', 'restaurant', CategoryKind.expense),
    _cat('default:groceries', 'Supermercado', 'shopping_cart', CategoryKind.expense),
    _cat('default:transport', 'Transporte', 'directions_bus', CategoryKind.expense),
    _cat('default:utilities', 'Servicios', 'bolt', CategoryKind.expense),
    _cat('default:housing', 'Vivienda', 'home', CategoryKind.expense),
    _cat('default:health', 'Salud', 'favorite', CategoryKind.expense),
    _cat('default:education', 'Educación', 'school', CategoryKind.expense),
    _cat('default:entertainment', 'Entretenimiento', 'movie', CategoryKind.expense),
    _cat('default:shopping', 'Compras', 'shopping_bag', CategoryKind.expense),
    _cat('default:subscriptions', 'Suscripciones', 'subscriptions', CategoryKind.expense),
    _cat('default:gifts-donations', 'Regalos', 'card_giftcard', CategoryKind.expense),
    _cat('default:other-expense', 'Otros gastos', 'more_horiz', CategoryKind.expense),
    _cat('default:salary', 'Sueldo', 'payments', CategoryKind.income),
  ];

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _dark ? darkTheme : lightTheme,
      child: Builder(builder: (context) => _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final brightness = Theme.of(context).brightness;

    Widget section(String title, Widget child) => Padding(
      padding: const EdgeInsets.only(top: Space.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Text(title.toUpperCase(), style: t.label),
          ),
          const SizedBox(height: Space.md),
          child,
        ],
      ),
    );
    Widget padded(Widget w) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: w,
    );

    final swatches = <(String, Color)>[
      ('background', c.background),
      ('surface', c.surface),
      ('surfaceAlt', c.surfaceAlt),
      ('border', c.border),
      ('accent', c.accent),
      ('accentSoft', c.accentSoft),
      ('income', c.income),
      ('expense', c.expense),
      ('transfer', c.transfer),
      ('danger', c.danger),
    ];

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: const Text('Galería de componentes'),
        actions: [
          Row(
            children: [
              Icon(_dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, size: 20),
              Switch(value: _dark, onChanged: (v) => setState(() => _dark = v)),
              const SizedBox(width: Space.sm),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Space.xxl),
        children: [
          section(
            'Montos',
            padded(
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Saldo total', style: t.caption),
                    const SizedBox(height: Space.xs),
                    const AmountText(2418750, 'GTQ', size: AmountSize.xl),
                    const SizedBox(height: Space.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AmountText(
                          350000,
                          'GTQ',
                          size: AmountSize.m,
                          color: c.income,
                          showPlus: true,
                        ),
                        AmountText(-4550, 'GTQ', size: AmountSize.m, color: c.expense),
                        AmountText(30000, 'GTQ', size: AmountSize.m, color: c.transfer),
                      ],
                    ),
                    const SizedBox(height: Space.sm),
                    const AmountText(111111, 'GTQ', size: AmountSize.l),
                    const AmountText(100000, 'GTQ', size: AmountSize.l),
                  ],
                ),
              ),
            ),
          ),
          section(
            'Selector de tipo',
            padded(
              TypeSwitcher<String>(
                options: const [
                  ('expense', 'Gasto'),
                  ('income', 'Ingreso'),
                  ('transfer', 'Transferencia'),
                ],
                value: _type,
                onChanged: (v) => setState(() => _type = v),
                colorOf: (v) => switch (v) {
                  'income' => c.income,
                  'transfer' => c.transfer,
                  _ => c.expense,
                },
              ),
            ),
          ),
          section('Monto (entrada)', padded(AmountInput(controller: _amount, currency: 'GTQ'))),
          section(
            'Chips de cuenta',
            AccountChips(
              accounts: _accounts,
              selectedId: _account,
              onSelected: (id) => setState(() => _account = id ?? _account),
            ),
          ),
          section(
            'Categorías',
            padded(
              Wrap(
                spacing: Space.md,
                runSpacing: Space.md,
                children: [
                  for (final cat in _categories.take(8))
                    CategoryAvatar(
                      icon: categoryStyleFor(cat, brightness).icon,
                      color: categoryStyleFor(cat, brightness).color,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.md),
          padded(
            AppButton(
              label: 'Elegir categoría',
              kind: AppButtonKind.secondary,
              icon: Icons.grid_view_rounded,
              onPressed: () async {
                final pick = await showCategoryPicker(
                  context,
                  categories: _categories.where((c) => c.kind == CategoryKind.expense).toList(),
                  selectedId: _category,
                );
                if (pick != null) setState(() => _category = pick.id);
              },
            ),
          ),
          section(
            'Lista de movimientos',
            Container(
              decoration: BoxDecoration(
                color: c.surface,
                border: Border.symmetric(horizontal: BorderSide(color: c.border)),
              ),
              child: Column(
                children: [
                  DayHeader(
                    label: 'Hoy',
                    total: AmountText(-16200, 'GTQ', size: AmountSize.s, color: c.textSecondary),
                  ),
                  ..._rows(context, brightness),
                ],
              ),
            ),
          ),
          section(
            'Botones',
            padded(
              Column(
                children: [
                  AppButton(label: 'Guardar gasto', onPressed: () {}),
                  const SizedBox(height: Space.sm),
                  AppButton(label: 'Cancelar', onPressed: () {}, kind: AppButtonKind.secondary),
                  const SizedBox(height: Space.xs),
                  AppButton(label: 'Más detalles', onPressed: () {}, kind: AppButtonKind.text),
                  const SizedBox(height: Space.sm),
                  const AppButton(label: 'Deshabilitado', onPressed: null),
                ],
              ),
            ),
          ),
          section(
            'Campos',
            padded(
              Column(
                children: [
                  const TextField(
                    decoration: InputDecoration(
                      labelText: 'Nombre',
                      errorText: 'El nombre no puede estar vacío',
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  const TextField(decoration: InputDecoration(labelText: 'Nota')),
                  const SizedBox(height: Space.md),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        PickerRow(
                          label: 'Categoría',
                          value: 'Comida',
                          leading: CategoryAvatar(
                            icon: categoryStyleFor(_categories.first, brightness).icon,
                            color: categoryStyleFor(_categories.first, brightness).color,
                            size: 36,
                          ),
                          onTap: () {},
                        ),
                        Divider(color: c.border),
                        PickerRow(
                          label: 'Fecha',
                          value: 'Hoy',
                          leading: Icon(Icons.calendar_today_rounded, color: c.textSecondary),
                          onTap: () {},
                          errorText: 'Fecha inválida',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          section(
            'Ícono y color de categoría',
            padded(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconChooser(
                    icons: categoryIconChoices.take(10).toList(),
                    selected: _icon,
                    color: adaptToBrightness(_color, brightness),
                    onChanged: (v) => setState(() => _icon = v),
                  ),
                  const SizedBox(height: Space.lg),
                  ColorChooser(
                    colors: categoryColorChoices,
                    selected: _color,
                    onChanged: (v) => setState(() => _color = v),
                  ),
                ],
              ),
            ),
          ),
          section(
            'Tarjeta: uso, desglose y estado',
            padded(
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const UsageBar(fraction: 0.35),
                    const SizedBox(height: Space.xs),
                    const UsageBar(fraction: 0.95),
                    const SizedBox(height: Space.md),
                    const AmountRow(label: 'Compras', minor: 75000, currency: 'GTQ'),
                    AmountRow(
                      label: 'Devoluciones',
                      minor: 5000,
                      currency: 'GTQ',
                      showPlus: true,
                      color: c.income,
                      note: 'Ya restadas del estimado',
                    ),
                    const Divider(),
                    const AmountRow(label: 'Estimado al corte', minor: 70000, currency: 'GTQ', strong: true),
                    const SizedBox(height: Space.sm),
                    Wrap(
                      spacing: Space.sm,
                      runSpacing: Space.sm,
                      children: [
                        StatusBadge(label: 'Pagado', tone: c.income),
                        StatusBadge(label: 'Mínimo cubierto', tone: c.accent),
                        StatusBadge(label: 'Pendiente', tone: c.textSecondary),
                        StatusBadge(label: 'Vencido', tone: c.expense),
                      ],
                    ),
                    const SizedBox(height: Space.md),
                    const InfoNote(text: 'Próximo corte: 21 oct · Pago hasta: 15 nov'),
                  ],
                ),
              ),
            ),
          ),
          section(
            'Selector de mes',
            padded(
              AppCard(
                padding: EdgeInsets.zero,
                child: MonthSelector(
                  month: _month,
                  onPrevious: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                  onNext: _month.isBefore(DateTime(2026, 9))
                      ? () => setState(() => _month = DateTime(_month.year, _month.month + 1))
                      : null,
                ),
              ),
            ),
          ),
          section(
            'Filas de lista',
            padded(
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    AppListRow(
                      leading: Icon(Icons.category_rounded, color: c.accent),
                      title: 'Categorías',
                      subtitle: 'Gastos e ingresos',
                      onTap: () {},
                    ),
                    Divider(color: c.border),
                    AppListRow(
                      leading: Icon(Icons.local_offer_rounded, color: c.textTertiary),
                      title: 'Archivada',
                      subtitle: 'Atenuada, pero tocable',
                      dimmed: true,
                      onTap: () {},
                    ),
                    Divider(color: c.border),
                    AppListRow(
                      leading: Icon(Icons.handshake_rounded, color: c.textTertiary),
                      title: 'Deudas',
                      subtitle: 'Próximamente',
                    ),
                  ],
                ),
              ),
            ),
          ),
          section(
            'Estado vacío',
            SizedBox(
              height: 300,
              child: EmptyState(
                icon: Icons.receipt_long_rounded,
                title: 'Aún no hay movimientos',
                message: 'Registra tu primer gasto o ingreso para verlo aquí.',
                actionLabel: 'Registrar movimiento',
                onAction: () {},
              ),
            ),
          ),
          section(
            'Barra inferior',
            AppBottomBar(
              currentIndex: _tab,
              onSelected: (i) => setState(() => _tab = i),
              onAction: () {},
              items: const [
                BottomBarItem(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home_rounded,
                  label: 'Inicio',
                ),
                BottomBarItem(
                  icon: Icons.receipt_long_outlined,
                  selectedIcon: Icons.receipt_long_rounded,
                  label: 'Movimientos',
                ),
                BottomBarItem(
                  icon: Icons.account_balance_wallet_outlined,
                  selectedIcon: Icons.account_balance_wallet_rounded,
                  label: 'Cuentas',
                ),
                BottomBarItem(
                  icon: Icons.more_horiz_rounded,
                  selectedIcon: Icons.more_horiz_rounded,
                  label: 'Más',
                ),
              ],
            ),
          ),
          section(
            'Colores',
            padded(
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: [
                  for (final (name, color) in swatches)
                    SizedBox(
                      width: 96,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(Radii.sm),
                              border: Border.all(color: c.border),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(name, style: t.label.copyWith(fontSize: 11)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          section(
            'Tipografía',
            padded(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Título 22 bold', style: t.title),
                  Text('Encabezado 17 semibold', style: t.heading),
                  Text('Cuerpo 15 regular con detalle', style: t.body),
                  Text('Cuerpo destacado 15 medium', style: t.bodyStrong),
                  Text('Texto de apoyo 13 regular', style: t.caption),
                  Text('ETIQUETA 12 MEDIUM', style: t.label),
                  Text('0123456789 · 1,111.11', style: t.amountM),
                  Text('0123456789 · 1,000.00', style: t.amountM),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _rows(BuildContext context, Brightness brightness) {
    final c = context.colors;
    Widget row(String catId, String title, String? sub, int minor, {bool income = false}) {
      final cat = _categories.where((e) => e.id == catId).firstOrNull;
      final style = categoryStyleFor(cat, brightness);
      return TransactionRow(
        icon: style.icon,
        iconColor: style.color,
        title: title,
        subtitle: sub,
        onTap: () {},
        amount: AmountText(
          income ? minor : -minor,
          'GTQ',
          color: income ? c.income : null,
          showPlus: income,
        ),
      );
    }

    return [
      row('default:food', 'Comida', 'Efectivo · Almuerzo', 4550),
      Divider(indent: 76, color: c.border),
      row('default:transport', 'Transporte', 'Banrural', 2500),
      Divider(indent: 76, color: c.border),
      TransactionRow(
        icon: transferIcon,
        iconColor: c.transfer,
        title: 'Transferencia',
        subtitle: 'Banrural → Efectivo',
        onTap: () {},
        amount: AmountText(30000, 'GTQ', color: c.transfer),
      ),
      Divider(indent: 76, color: c.border),
      row('default:salary', 'Sueldo', 'Banrural', 350000, income: true),
    ];
  }
}
