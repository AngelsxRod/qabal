import 'package:finanzas/data/database/app_database.dart';
import 'package:finanzas/ui/transactions/transaction_filter_params.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sin parámetros no hay filtros', () {
    final p = TransactionFilterParams.fromQuery({});
    expect(p.isEmpty, isTrue);
    expect(p.activeCount, 0);
    expect(p.toQuery(), isEmpty);
    expect(p.rangeLabel, isNull);
  });

  test('ida y vuelta por la URL', () {
    final query = {
      'cuenta': 'a1',
      'tipo': 'income',
      'categoria': 'default:salary',
      'etiqueta': 't1',
      'desde': '2026-09-01',
      'hasta': '2026-09-15',
    };
    final p = TransactionFilterParams.fromQuery(query);
    expect(p.accountId, 'a1');
    expect(p.type, TransactionType.income);
    expect(p.from, DateTime(2026, 9, 1));
    expect(p.to, DateTime(2026, 9, 15));
    expect(p.activeCount, 5); // el rango de fechas cuenta como uno
    expect(p.toQuery(), query);
    expect(p.rangeLabel, '1 sep 2026 – 15 sep 2026');
  });

  test('"hasta" es inclusivo: el filtro llega hasta el día siguiente (exclusivo)', () {
    final f = TransactionFilterParams.fromQuery({'desde': '2026-09-01', 'hasta': '2026-09-30'})
        .toFilter();
    expect(f.from, DateTime(2026, 9, 1));
    expect(f.to, DateTime(2026, 10, 1));

    final endOfYear = TransactionFilterParams.fromQuery({'hasta': '2026-12-31'}).toFilter();
    expect(endOfYear.to, DateTime(2027, 1, 1));
  });

  test('ignora valores inválidos en lugar de fallar', () {
    final p = TransactionFilterParams.fromQuery({
      'tipo': 'nada',
      'desde': 'ayer',
      'hasta': '2026-02-31',
    });
    expect(p.isEmpty, isTrue);
  });

  test('etiqueta de rangos abiertos', () {
    expect(TransactionFilterParams(from: DateTime(2026, 9, 1)).rangeLabel, 'Desde 1 sep 2026');
    expect(TransactionFilterParams(to: DateTime(2026, 9, 1)).rangeLabel, 'Hasta 1 sep 2026');
  });
}
