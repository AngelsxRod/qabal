import 'package:finanzas/data/database/app_database.dart';
import 'package:finanzas/data/repositories/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dos filtros con los mismos valores son iguales y comparten hash', () {
    final a = TransactionFilter(
      accountId: 'a',
      type: TransactionType.expense,
      from: DateTime(2026, 9, 1),
      to: DateTime(2026, 10, 1),
      limit: 50,
    );
    final b = TransactionFilter(
      accountId: 'a',
      type: TransactionType.expense,
      from: DateTime(2026, 9, 1),
      to: DateTime(2026, 10, 1),
      limit: 50,
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect({a: 1}[b], 1);
  });

  test('cualquier campo distinto los hace diferentes', () {
    const base = TransactionFilter(accountId: 'a', limit: 50);
    final others = <TransactionFilter>[
      const TransactionFilter(accountId: 'b', limit: 50),
      const TransactionFilter(accountId: 'a', limit: 100),
      const TransactionFilter(accountId: 'a', limit: 50, offset: 50),
      const TransactionFilter(accountId: 'a', limit: 50, categoryId: 'c'),
      const TransactionFilter(accountId: 'a', limit: 50, contactId: 'c'),
      const TransactionFilter(accountId: 'a', limit: 50, debtId: 'd'),
      const TransactionFilter(accountId: 'a', limit: 50, statementId: 's'),
      const TransactionFilter(accountId: 'a', limit: 50, tagId: 't'),
      const TransactionFilter(accountId: 'a', limit: 50, type: TransactionType.income),
      TransactionFilter(accountId: 'a', limit: 50, from: DateTime(2026)),
      TransactionFilter(accountId: 'a', limit: 50, to: DateTime(2026)),
    ];
    for (final o in others) {
      expect(o, isNot(base));
    }
  });
}
