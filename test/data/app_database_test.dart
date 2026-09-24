import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:finanzas/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('esquema base', baseTests);
  group('esquema ampliado', extendedTests);
}

void baseTests() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<String> newAccount() async {
    final a = await db.into(db.accounts).insertReturning(
          AccountsCompanion.insert(
              name: 'Efectivo', type: AccountType.cash, currency: 'GTQ'),
        );
    return a.id;
  }

  test('genera UUID y valores por defecto', () async {
    final id = await newAccount();
    final a = await (db.select(db.accounts)..where((t) => t.id.equals(id))).getSingle();
    expect(a.id, hasLength(36));
    expect(a.initialBalanceMinor, 0);
    expect(a.isArchived, isFalse);
  });

  test('inserta transacción con categoría y la consulta', () async {
    final acc = await newAccount();
    final cat = await db.into(db.categories).insertReturning(
        CategoriesCompanion.insert(name: 'Comida', kind: CategoryKind.expense));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          accountId: acc,
          categoryId: Value(cat.id),
          type: TransactionType.expense,
          amountMinor: 1550,
          occurredAt: DateTime(2026, 9, 24),
        ));
    final rows = await db.select(db.transactions).get();
    expect(rows.single.amountMinor, 1550);
    expect(rows.single.type, TransactionType.expense);
  });

  test('rechaza monto <= 0', () async {
    final acc = await newAccount();
    expect(
      db.into(db.transactions).insert(TransactionsCompanion.insert(
            accountId: acc,
            type: TransactionType.income,
            amountMinor: 0,
            occurredAt: DateTime.now(),
          )),
      throwsA(isA<Exception>()),
    );
  });

  test('foreign keys activas: cuenta inexistente falla', () async {
    expect(
      db.into(db.transactions).insert(TransactionsCompanion.insert(
            accountId: 'no-existe',
            type: TransactionType.income,
            amountMinor: 100,
            occurredAt: DateTime.now(),
          )),
      throwsA(isA<Exception>()),
    );
  });

  test('no permite borrar cuenta con transacciones (restrict)', () async {
    final acc = await newAccount();
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          accountId: acc,
          type: TransactionType.income,
          amountMinor: 100,
          occurredAt: DateTime.now(),
        ));
    expect(
      (db.delete(db.accounts)..where((t) => t.id.equals(acc))).go(),
      throwsA(isA<Exception>()),
    );
  });
}

// ---------------------------------------------------------------------------
// Tarjetas, contactos, deudas y etiquetas
// ---------------------------------------------------------------------------
void extendedTests() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<String> account(String name, AccountType type, {String currency = 'GTQ'}) async =>
      (await db.into(db.accounts).insertReturning(
              AccountsCompanion.insert(name: name, type: type, currency: currency)))
          .id;

  Future<String> card() async {
    final id = await account('Visa', AccountType.creditCard);
    await db.into(db.creditCardDetails).insert(CreditCardDetailsCompanion.insert(
        accountId: id, creditLimitMinor: 1000000, statementDay: 21, dueDay: 15));
    return id;
  }

  Future<String> statement(String cardId, {DateTime? closing}) async =>
      (await db.into(db.creditCardStatements).insertReturning(
              CreditCardStatementsCompanion.insert(
        accountId: cardId,
        periodStart: DateTime(2026, 8, 22),
        closingDate: closing ?? DateTime(2026, 9, 21),
        dueDate: DateTime(2026, 10, 15),
        statementBalanceMinor: 50000,
        minimumPaymentMinor: 5000,
      )))
          .id;

  Future<String> contact() async => (await db
          .into(db.contacts)
          .insertReturning(ContactsCompanion.insert(name: 'Mi empresa')))
      .id;

  Future<String> debt(String contactId) async =>
      (await db.into(db.debts).insertReturning(DebtsCompanion.insert(
        contactId: contactId,
        direction: DebtDirection.owedToMe,
        principalMinor: 50000,
        currency: 'GTQ',
        description: 'Préstamo',
        startDate: DateTime(2026, 9, 1),
      )))
          .id;

  TransactionsCompanion tx({
    required String accountId,
    TransactionType type = TransactionType.expense,
    int amount = 100,
    String? transferTo,
    int? transferAmount,
    String? statementId,
    String? debtId,
    String? contactId,
  }) =>
      TransactionsCompanion.insert(
        accountId: accountId,
        type: type,
        amountMinor: amount,
        occurredAt: DateTime(2026, 9, 10),
        transferAccountId: Value(transferTo),
        transferAmountMinor: Value(transferAmount),
        statementId: Value(statementId),
        debtId: Value(debtId),
        contactId: Value(contactId),
      );

  group('CreditCardDetails', () {
    test('acepta datos válidos y una sola fila por cuenta', () async {
      final id = await card();
      expect(
        db.into(db.creditCardDetails).insert(CreditCardDetailsCompanion.insert(
            accountId: id, creditLimitMinor: 1, statementDay: 1, dueDay: 1)),
        throwsA(isA<Exception>()),
      );
    });
    test('rechaza días fuera de 1–31 y límite <= 0', () async {
      for (final (limit, s, d) in [(1000, 0, 15), (1000, 21, 32), (0, 21, 15)]) {
        final id = await account('T$limit$s$d', AccountType.creditCard);
        expect(
          db.into(db.creditCardDetails).insert(CreditCardDetailsCompanion.insert(
              accountId: id, creditLimitMinor: limit, statementDay: s, dueDay: d)),
          throwsA(isA<Exception>()),
        );
      }
    });
  });

  group('CreditCardStatements', () {
    test('guarda fechas como texto yyyy-MM-dd y las lee sin hora', () async {
      final c = await card();
      final id = await statement(c);
      final raw = await db
          .customSelect('SELECT closing_date FROM credit_card_statements WHERE id = ?',
              variables: [Variable(id)])
          .getSingle();
      expect(raw.read<String>('closing_date'), '2026-09-21');
      final row = await db.select(db.creditCardStatements).getSingle();
      expect(row.closingDate, DateTime(2026, 9, 21));
      expect(row.dueDate, DateTime(2026, 10, 15));
    });
    test('un corte por cuenta (UNIQUE)', () async {
      final c = await card();
      await statement(c);
      expect(statement(c), throwsA(isA<Exception>()));
      await statement(c, closing: DateTime(2026, 10, 21));
    });
    test('mínimo no puede superar el saldo', () async {
      final c = await card();
      expect(
        db.into(db.creditCardStatements).insert(CreditCardStatementsCompanion.insert(
              accountId: c,
              periodStart: DateTime(2026, 8, 22),
              closingDate: DateTime(2026, 9, 21),
              dueDate: DateTime(2026, 10, 15),
              statementBalanceMinor: 1000,
              minimumPaymentMinor: 2000,
            )),
        throwsA(isA<Exception>()),
      );
    });
    test('saldo cero es válido', () async {
      final c = await card();
      await db.into(db.creditCardStatements).insert(CreditCardStatementsCompanion.insert(
            accountId: c,
            periodStart: DateTime(2026, 8, 22),
            closingDate: DateTime(2026, 9, 21),
            dueDate: DateTime(2026, 10, 15),
            statementBalanceMinor: 0,
            minimumPaymentMinor: 0,
          ));
    });
  });

  group('CHECKs de Transactions', () {
    test('transferencia válida (con estado de cuenta)', () async {
      final bank = await account('Banco', AccountType.bank);
      final c = await card();
      final st = await statement(c);
      await db.into(db.transactions).insert(tx(
          accountId: bank, type: TransactionType.transfer, transferTo: c, statementId: st));
    });
    test('transfer requiere destino', () async {
      final a = await account('A', AccountType.cash);
      expect(db.into(db.transactions).insert(tx(accountId: a, type: TransactionType.transfer)),
          throwsA(isA<Exception>()));
    });
    test('destino distinto del origen', () async {
      final a = await account('A', AccountType.cash);
      expect(
          db.into(db.transactions).insert(
              tx(accountId: a, type: TransactionType.transfer, transferTo: a)),
          throwsA(isA<Exception>()));
    });
    test('expense/income no llevan destino ni monto de transferencia', () async {
      final a = await account('A', AccountType.cash);
      final b = await account('B', AccountType.bank);
      expect(db.into(db.transactions).insert(tx(accountId: a, transferTo: b)),
          throwsA(isA<Exception>()));
      expect(db.into(db.transactions).insert(tx(accountId: a, transferAmount: 50)),
          throwsA(isA<Exception>()));
    });
    test('statementId solo en transferencias', () async {
      final c = await card();
      final st = await statement(c);
      expect(db.into(db.transactions).insert(tx(accountId: c, statementId: st)),
          throwsA(isA<Exception>()));
    });
    test('debtId no se permite en transferencias', () async {
      final a = await account('A', AccountType.cash);
      final b = await account('B', AccountType.bank);
      final d = await debt(await contact());
      expect(
          db.into(db.transactions).insert(
              tx(accountId: a, type: TransactionType.transfer, transferTo: b, debtId: d)),
          throwsA(isA<Exception>()));
    });
    test('abono de deuda como income con debtId', () async {
      final a = await account('A', AccountType.cash);
      final d = await debt(await contact());
      await db
          .into(db.transactions)
          .insert(tx(accountId: a, type: TransactionType.income, debtId: d));
    });
  });

  group('Claves foráneas', () {
    test('contacto con movimientos no se puede borrar (restrict)', () async {
      final a = await account('A', AccountType.cash);
      final c = await contact();
      await db.into(db.transactions).insert(
          tx(accountId: a, type: TransactionType.income, contactId: c));
      expect((db.delete(db.contacts)..where((t) => t.id.equals(c))).go(),
          throwsA(isA<Exception>()));
    });
    test('deuda con movimientos ni contacto con deudas se pueden borrar', () async {
      final a = await account('A', AccountType.cash);
      final c = await contact();
      final d = await debt(c);
      expect((db.delete(db.contacts)..where((t) => t.id.equals(c))).go(),
          throwsA(isA<Exception>()));
      await db.into(db.transactions).insert(
          tx(accountId: a, type: TransactionType.income, debtId: d));
      expect((db.delete(db.debts)..where((t) => t.id.equals(d))).go(),
          throwsA(isA<Exception>()));
    });
    test('borrar un estado de cuenta deja el pago con statementId nulo', () async {
      final bank = await account('Banco', AccountType.bank);
      final c = await card();
      final st = await statement(c);
      await db.into(db.transactions).insert(tx(
          accountId: bank, type: TransactionType.transfer, transferTo: c, statementId: st));
      await (db.delete(db.creditCardStatements)..where((t) => t.id.equals(st))).go();
      final t = await db.select(db.transactions).getSingle();
      expect(t.statementId, isNull);
    });
    test('cuenta con detalles de tarjeta no se puede borrar (restrict)', () async {
      final c = await card();
      expect((db.delete(db.accounts)..where((t) => t.id.equals(c))).go(),
          throwsA(isA<Exception>()));
    });
  });

  group('Deudas', () {
    test('estado por defecto open y principal > 0', () async {
      final c = await contact();
      final d = await debt(c);
      final row = await (db.select(db.debts)..where((t) => t.id.equals(d))).getSingle();
      expect(row.status, DebtStatus.open);
      expect(row.dueDate, isNull);
      expect(
        db.into(db.debts).insert(DebtsCompanion.insert(
              contactId: c,
              direction: DebtDirection.iOwe,
              principalMinor: 0,
              currency: 'GTQ',
              description: 'x',
              startDate: DateTime(2026, 9, 1),
            )),
        throwsA(isA<Exception>()),
      );
    });
    test('fecha de vencimiento opcional se guarda como fecha', () async {
      final c = await contact();
      await db.into(db.debts).insert(DebtsCompanion.insert(
            contactId: c,
            direction: DebtDirection.iOwe,
            principalMinor: 100,
            currency: 'GTQ',
            description: 'Préstamo',
            startDate: DateTime(2026, 9, 1),
            dueDate: Value(DateTime(2026, 12, 31, 18, 45)),
          ));
      final row = await db.select(db.debts).getSingle();
      expect(row.dueDate, DateTime(2026, 12, 31));
    });
  });

  group('Etiquetas', () {
    test('nombre único sin distinguir mayúsculas', () async {
      await db.into(db.tags).insert(TagsCompanion.insert(name: 'Viaje'));
      expect(db.into(db.tags).insert(TagsCompanion.insert(name: 'viaje')),
          throwsA(isA<Exception>()));
    });
    test('borrar transacción o etiqueta elimina solo la asociación', () async {
      final a = await account('A', AccountType.cash);
      final t1 = await db.into(db.transactions).insertReturning(tx(accountId: a));
      final t2 = await db.into(db.transactions).insertReturning(tx(accountId: a));
      final tag = await db.into(db.tags).insertReturning(TagsCompanion.insert(name: 'Casa'));
      await db.into(db.transactionTags)
          .insert(TransactionTagsCompanion.insert(transactionId: t1.id, tagId: tag.id));
      await db.into(db.transactionTags)
          .insert(TransactionTagsCompanion.insert(transactionId: t2.id, tagId: tag.id));
      await (db.delete(db.transactions)..where((t) => t.id.equals(t1.id))).go();
      expect(await db.select(db.transactionTags).get(), hasLength(1));
      await (db.delete(db.tags)..where((t) => t.id.equals(tag.id))).go();
      expect(await db.select(db.transactionTags).get(), isEmpty);
      expect(await db.select(db.transactions).get(), hasLength(1));
    });
  });
}
