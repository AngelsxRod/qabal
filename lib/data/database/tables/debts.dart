// ignore_for_file: recursive_getters (patrón de Drift para CHECK en columnas)

import 'package:drift/drift.dart';

import '../date_only_converter.dart';
import 'contacts.dart';
import 'enums.dart';
import 'ids.dart';

/// Deuda con una persona (las tarjetas de crédito NO van aquí). El saldo
/// pendiente se calcula: principal menos los abonos (transacciones con
/// `debtId` cuyo tipo es el de abono para la dirección de la deuda).
@TableIndex(name: 'idx_debts_contact', columns: {#contactId})
@TableIndex(name: 'idx_debts_status', columns: {#status})
class Debts extends Table {
  TextColumn get id => text().clientDefault(() => newId())();
  TextColumn get contactId =>
      text().references(Contacts, #id, onDelete: KeyAction.restrict)();
  TextColumn get direction => textEnum<DebtDirection>()();
  IntColumn get principalMinor => integer().check(principalMinor.isBiggerThanValue(0))();
  TextColumn get currency => text().withLength(min: 3, max: 3)();
  TextColumn get description => text().withLength(min: 1, max: 200)();
  TextColumn get startDate => text().map(const DateOnlyConverter())();
  TextColumn get dueDate => text().nullable().map(const DateOnlyConverter())();
  TextColumn get status =>
      textEnum<DebtStatus>().withDefault(Constant(DebtStatus.open.name))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {id};
}
