import 'package:drift/native.dart';
import 'package:finanzas/data/database/app_database.dart';
import 'package:finanzas/data/repositories/account_repository.dart';
import 'package:finanzas/data/repositories/category_repository.dart';
import 'package:finanzas/data/repositories/contact_repository.dart';
import 'package:finanzas/data/repositories/credit_card_repository.dart';
import 'package:finanzas/data/repositories/debt_repository.dart';
import 'package:finanzas/data/repositories/models.dart';
import 'package:finanzas/data/repositories/tag_repository.dart';
import 'package:finanzas/data/repositories/transaction_repository.dart';

/// Reloj controlable para pruebas (segundos enteros: Drift guarda unix).
class FakeClock {
  FakeClock(this.current);

  DateTime current;

  DateTime call() => current;
}

/// Base en memoria, reloj falso y todos los repositorios.
class TestEnv {
  TestEnv([DateTime? start])
      : clock = FakeClock(start ?? DateTime(2026, 9, 1, 10)),
        db = AppDatabase.forTesting(NativeDatabase.memory()) {
    accounts = AccountRepository(db, now: clock.call);
    categories = CategoryRepository(db, now: clock.call);
    contacts = ContactRepository(db, now: clock.call);
    tags = TagRepository(db, now: clock.call);
    transactions = TransactionRepository(db, now: clock.call);
    debts = DebtRepository(db, now: clock.call);
    cards = CreditCardRepository(db, now: clock.call);
  }

  final FakeClock clock;
  final AppDatabase db;
  late final AccountRepository accounts;
  late final CategoryRepository categories;
  late final ContactRepository contacts;
  late final TagRepository tags;
  late final TransactionRepository transactions;
  late final DebtRepository debts;
  late final CreditCardRepository cards;

  Future<void> close() => db.close();

  Future<Account> cash({String name = 'Efectivo', String currency = 'GTQ', int initial = 0}) =>
      accounts.create(AccountInput(
          name: name, type: AccountType.cash, currency: currency, initialBalanceMinor: initial));

  Future<Account> bank({String name = 'Banco', String currency = 'GTQ', int initial = 0}) =>
      accounts.create(AccountInput(
          name: name, type: AccountType.bank, currency: currency, initialBalanceMinor: initial));

  Future<Account> card({
    String name = 'Visa',
    int limit = 1000000,
    int statementDay = 21,
    int dueDay = 15,
    int? minPaymentBp = 1000,
    int initial = 0,
  }) =>
      accounts.create(
        AccountInput(
            name: name,
            type: AccountType.creditCard,
            currency: 'GTQ',
            initialBalanceMinor: initial),
        card: CreditCardSettings(
            creditLimitMinor: limit,
            statementDay: statementDay,
            dueDay: dueDay,
            minPaymentBp: minPaymentBp),
      );

  Future<Transaction> expense(String accountId, int amount, DateTime at,
          {String? categoryId, String? debtId, String? contactId}) =>
      transactions.create(TransactionInput(
          accountId: accountId,
          type: TransactionType.expense,
          amountMinor: amount,
          occurredAt: at,
          categoryId: categoryId,
          debtId: debtId,
          contactId: contactId));

  Future<Transaction> income(String accountId, int amount, DateTime at,
          {String? categoryId, String? debtId, String? contactId}) =>
      transactions.create(TransactionInput(
          accountId: accountId,
          type: TransactionType.income,
          amountMinor: amount,
          occurredAt: at,
          categoryId: categoryId,
          debtId: debtId,
          contactId: contactId));

  Future<Transaction> transfer(String from, String to, int amount, DateTime at,
          {int? destAmount, String? statementId, bool autoAssign = true}) =>
      transactions.create(
        TransactionInput(
            accountId: from,
            type: TransactionType.transfer,
            amountMinor: amount,
            occurredAt: at,
            transferAccountId: to,
            transferAmountMinor: destAmount,
            statementId: statementId),
        autoAssignStatement: autoAssign,
      );

  Future<Contact> contact([String name = 'Persona']) =>
      contacts.create(ContactInput(name: name));
}
