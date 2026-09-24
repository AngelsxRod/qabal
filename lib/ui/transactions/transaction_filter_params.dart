import '../../app/providers.dart';
import '../../core/format/dates.dart';

/// Filtros de la pestaña Movimientos tal como viajan en la URL
/// (`/movimientos?cuenta=…&tipo=…`), para que sobrevivan a la navegación y
/// se puedan abrir desde otras pantallas.
///
/// `hasta` es inclusivo (el último día que se ve); el filtro del repositorio
/// usa un límite superior exclusivo, así que se convierte al día siguiente.
class TransactionFilterParams {
  const TransactionFilterParams({
    this.accountId,
    this.type,
    this.categoryId,
    this.tagId,
    this.from,
    this.to,
  });

  final String? accountId;
  final TransactionType? type;
  final String? categoryId;
  final String? tagId;
  final DateTime? from;
  final DateTime? to;

  bool get isEmpty =>
      accountId == null &&
      type == null &&
      categoryId == null &&
      tagId == null &&
      from == null &&
      to == null;

  /// Cantidad de filtros activos (el rango de fechas cuenta como uno).
  int get activeCount =>
      [accountId, type, categoryId, tagId].where((v) => v != null).length +
      (from != null || to != null ? 1 : 0);

  factory TransactionFilterParams.fromQuery(Map<String, String> q) {
    DateTime? date(String? v) {
      if (v == null) return null;
      final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(v);
      if (m == null) return null;
      final d = DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
      // Rechaza fechas que no existen (2026-02-31 se normalizaría a marzo).
      return d.month == int.parse(m[2]!) ? d : null;
    }

    return TransactionFilterParams(
      accountId: q['cuenta'],
      type: TransactionType.values.asNameMap()[q['tipo']],
      categoryId: q['categoria'],
      tagId: q['etiqueta'],
      from: date(q['desde']),
      to: date(q['hasta']),
    );
  }

  Map<String, String> toQuery() {
    final f = from;
    final t = to;
    return {
      'cuenta': ?accountId,
      'tipo': ?type?.name,
      'categoria': ?categoryId,
      'etiqueta': ?tagId,
      'desde': ?(f == null ? null : _ymd(f)),
      'hasta': ?(t == null ? null : _ymd(t)),
    };
  }

  TransactionFilter toFilter() => TransactionFilter(
    accountId: accountId,
    type: type,
    categoryId: categoryId,
    tagId: tagId,
    from: from,
    to: to == null ? null : DateTime(to!.year, to!.month, to!.day + 1),
  );

  static String _ymd(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';
  }

  /// Texto corto del rango, p. ej. `1 sep 2026 – 15 sep 2026`.
  String? get rangeLabel {
    if (from == null && to == null) return null;
    if (from != null && to != null) return '${formatDate(from!)} – ${formatDate(to!)}';
    return from != null ? 'Desde ${formatDate(from!)}' : 'Hasta ${formatDate(to!)}';
  }
}
