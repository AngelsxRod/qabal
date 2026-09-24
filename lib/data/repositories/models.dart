import '../database/app_database.dart';
import '../../domain/credit_card/card_cycle.dart';
import '../../domain/credit_card/statement_status.dart';

// ---------------------------------------------------------------------------
// Reglas de movimientos de deuda
// ---------------------------------------------------------------------------

/// Tipo del movimiento que origina la deuda (dinero prestado o recibido).
TransactionType originTypeOf(DebtDirection d) =>
    d == DebtDirection.owedToMe ? TransactionType.expense : TransactionType.income;

/// Tipo de los abonos: es el contrario al del origen.
TransactionType repaymentTypeOf(DebtDirection d) =>
    d == DebtDirection.owedToMe ? TransactionType.income : TransactionType.expense;

// ---------------------------------------------------------------------------
// Entradas
// ---------------------------------------------------------------------------

/// Datos para crear una cuenta.
///
/// CONVENCIÓN DE SIGNO: en una tarjeta de crédito el saldo es negativo cuando
/// se debe dinero, así que `initialBalanceMinor` es **negativo** si la tarjeta
/// ya tenía deuda al empezar a usar la app (deuda 500.00 → `-50000`). La UI
/// debe convertir desde un valor de "deuda actual" positivo. En cuentas
/// normales es el saldo a favor.
class AccountInput {
  const AccountInput({
    required this.name,
    required this.type,
    required this.currency,
    this.initialBalanceMinor = 0,
  });

  final String name;
  final AccountType type;
  final String currency;
  final int initialBalanceMinor;
}

class CreditCardSettings {
  const CreditCardSettings({
    required this.creditLimitMinor,
    required this.statementDay,
    required this.dueDay,
    this.minPaymentBp,
  });

  final int creditLimitMinor;
  final int statementDay;
  final int dueDay;

  /// Pago mínimo estimado en puntos básicos (500 = 5 %).
  final int? minPaymentBp;
}

class CategoryInput {
  const CategoryInput({
    required this.name,
    required this.kind,
    this.parentId,
    this.icon,
    this.colorValue,
  });

  final String name;
  final CategoryKind kind;
  final String? parentId;
  final String? icon;
  final int? colorValue;
}

class ContactInput {
  const ContactInput({required this.name, this.type, this.note});

  final String name;
  final ContactType? type;
  final String? note;
}

class TransactionInput {
  const TransactionInput({
    required this.accountId,
    required this.type,
    required this.amountMinor,
    required this.occurredAt,
    this.categoryId,
    this.transferAccountId,
    this.transferAmountMinor,
    this.contactId,
    this.debtId,
    this.statementId,
    this.note,
    this.receiptPath,
  });

  final String accountId;
  final TransactionType type;
  final int amountMinor;
  final DateTime occurredAt;
  final String? categoryId;
  final String? transferAccountId;
  final int? transferAmountMinor;
  final String? contactId;
  final String? debtId;
  final String? statementId;
  final String? note;
  final String? receiptPath;

  TransactionInput withStatement(String? statementId) => TransactionInput(
        accountId: accountId,
        type: type,
        amountMinor: amountMinor,
        occurredAt: occurredAt,
        categoryId: categoryId,
        transferAccountId: transferAccountId,
        transferAmountMinor: transferAmountMinor,
        contactId: contactId,
        debtId: debtId,
        statementId: statementId,
        note: note,
        receiptPath: receiptPath,
      );
}

/// Filtros de listado de movimientos. `to` es exclusivo. `accountId` incluye
/// los movimientos de la cuenta y las transferencias que le llegan.
class TransactionFilter {
  const TransactionFilter({
    this.accountId,
    this.categoryId,
    this.contactId,
    this.debtId,
    this.statementId,
    this.tagId,
    this.type,
    this.from,
    this.to,
    this.limit,
    this.offset,
  });

  final String? accountId;
  final String? categoryId;
  final String? contactId;
  final String? debtId;
  final String? statementId;
  final String? tagId;
  final TransactionType? type;
  final DateTime? from;
  final DateTime? to;
  final int? limit;
  final int? offset;
}

class DebtInput {
  const DebtInput({
    required this.contactId,
    required this.direction,
    required this.principalMinor,
    required this.currency,
    required this.description,
    required this.startDate,
    this.dueDate,
  });

  final String contactId;
  final DebtDirection direction;
  final int principalMinor;
  final String currency;
  final String description;
  final DateTime startDate;
  final DateTime? dueDate;
}

/// Estado de cuenta según el banco. Si `periodStart` o `dueDate` se omiten, se
/// derivan del horario de la tarjeta a partir de `closingDate`.
class StatementInput {
  const StatementInput({
    required this.accountId,
    required this.closingDate,
    required this.statementBalanceMinor,
    required this.minimumPaymentMinor,
    this.periodStart,
    this.dueDate,
    this.note,
  });

  final String accountId;
  final DateTime closingDate;
  final int statementBalanceMinor;
  final int minimumPaymentMinor;
  final DateTime? periodStart;
  final DateTime? dueDate;
  final String? note;
}

// ---------------------------------------------------------------------------
// Vistas
// ---------------------------------------------------------------------------

class AccountBalance {
  const AccountBalance(this.account, this.balanceMinor);

  final Account account;

  /// Saldo calculado. En tarjetas de crédito, negativo = deuda.
  final int balanceMinor;
}

/// Movimientos de una tarjeta en la ventana de un ciclo.
///
/// `closingDebtMinor` = deuda inicial + compras + intereses + avances
/// − devoluciones − otros créditos − pagos.
class CycleMovements {
  const CycleMovements({
    required this.openingDebtMinor,
    required this.purchasesMinor,
    required this.interestMinor,
    required this.cashAdvancesMinor,
    required this.refundsMinor,
    required this.otherCreditsMinor,
    required this.paymentsMinor,
  });

  /// Deuda al inicio del ciclo (arrastra lo no pagado de ciclos anteriores).
  final int openingDebtMinor;

  /// `expense` de la tarjeta, salvo la categoría "Intereses y cargos".
  final int purchasesMinor;

  /// `expense` con la categoría del sistema "Intereses y cargos".
  final int interestMinor;

  /// Transferencias salientes de la tarjeta.
  final int cashAdvancesMinor;

  /// `income` con la categoría del sistema "Devoluciones".
  final int refundsMinor;

  /// Cualquier otro `income` a la tarjeta.
  final int otherCreditsMinor;

  /// Transferencias hacia la tarjeta.
  final int paymentsMinor;

  int get closingDebtMinor =>
      openingDebtMinor +
      purchasesMinor +
      interestMinor +
      cashAdvancesMinor -
      refundsMinor -
      otherCreditsMinor -
      paymentsMinor;
}

class CardCycleSummary {
  const CardCycleSummary({
    required this.cycle,
    required this.movements,
    required this.estimatedMinimumMinor,
    required this.previousStatementPendingMinor,
  });

  final CardCycle cycle;
  final CycleMovements movements;

  /// Deuda estimada al próximo corte (incluye lo arrastrado).
  int get estimatedClosingMinor => movements.closingDebtMinor;

  /// `ceil(estimado × minPaymentBp / 10000)`; nulo sin `minPaymentBp` o sin
  /// deuda.
  final int? estimatedMinimumMinor;

  /// Lo que falta pagar del último estado de cuenta registrado anterior al
  /// ciclo; nulo si no hay ninguno.
  final int? previousStatementPendingMinor;
}

class CardOverview {
  const CardOverview({
    required this.account,
    required this.settings,
    required this.balanceMinor,
    required this.summary,
  });

  final Account account;
  final CreditCardDetail settings;

  /// Saldo (negativo = deuda).
  final int balanceMinor;
  final CardCycleSummary summary;

  /// Deuda; negativa si hay saldo a favor.
  int get debtMinor => -balanceMinor;

  /// Cuánto debo (nunca negativo).
  int get owedMinor => debtMinor > 0 ? debtMinor : 0;

  /// Límite menos deuda; negativo si se excede el límite.
  int get availableCreditMinor => settings.creditLimitMinor - debtMinor;
}

class StatementView {
  const StatementView({
    required this.statement,
    required this.paidMinor,
    required this.status,
    required this.estimatedBalanceMinor,
    required this.movements,
  });

  final CreditCardStatement statement;

  /// Suma de las transferencias vinculadas con `statementId`.
  final int paidMinor;
  final StatementStatus status;

  /// Deuda al corte calculada por la app.
  final int estimatedBalanceMinor;

  /// Desglose de la ventana del estado de cuenta.
  final CycleMovements movements;

  /// Oficial − estimado. Positivo: el banco reporta más de lo registrado.
  int get differenceMinor => statement.statementBalanceMinor - estimatedBalanceMinor;
}

/// Totales de un período, por moneda (sin conversión). Excluye transferencias
/// y movimientos con `debtId`.
class PeriodTotals {
  const PeriodTotals({
    required this.currency,
    required this.incomeMinor,
    required this.expenseMinor,
    required this.refundsMinor,
  });

  final String currency;

  /// Ingresos sin contar la categoría del sistema "Devoluciones".
  final int incomeMinor;

  /// Gastos **netos**: ya restadas las devoluciones.
  final int expenseMinor;

  /// Devoluciones del período (cifra informativa; ya está restada en
  /// `expenseMinor`).
  final int refundsMinor;

  int get grossExpenseMinor => expenseMinor + refundsMinor;
}

class CategoryTotal {
  const CategoryTotal({
    required this.currency,
    required this.categoryId,
    required this.totalMinor,
  });

  final String currency;

  /// Nulo = sin categoría.
  final String? categoryId;

  /// En gastos, la línea de devoluciones (`system:refunds`) es negativa.
  final int totalMinor;
}

class DebtBalance {
  const DebtBalance({
    required this.debt,
    required this.paidMinor,
  });

  final Debt debt;

  /// Suma de abonos (no incluye el movimiento de origen).
  final int paidMinor;

  int get pendingMinor {
    final p = debt.principalMinor - paidMinor;
    return p > 0 ? p : 0;
  }

  int get excessMinor {
    final e = paidMinor - debt.principalMinor;
    return e > 0 ? e : 0;
  }

  bool get isFullyPaid => pendingMinor == 0;
}
