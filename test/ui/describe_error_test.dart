import 'package:finanzas/domain/errors.dart';
import 'package:finanzas/ui/common/describe_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('describeError', () {
    test('los errores de dominio se explican en español', () {
      expect(describeError(const InvalidAmountException()), 'El monto debe ser mayor que cero');
      expect(describeError(DuplicateNameException('Viajes')), 'Ya existe "Viajes".');
      expect(describeError(NotFoundException('Cuenta', 'x')), contains('Cuenta ya no existe'));
      expect(describeError(ArchivedAccountException('x')), contains('archivada'));
      expect(describeError(DebtClosedException('d', 'settled')), contains('saldada'));
      expect(describeError(const InvalidInputException('El nombre no puede estar vacío')),
          'El nombre no puede estar vacío');
    });

    test('lo desconocido no filtra detalles técnicos', () {
      final text = describeError(StateError('boom'));
      expect(text, contains('error inesperado'));
      expect(text, isNot(contains('boom')));
    });

    test('ningún error de dominio produce texto vacío', () {
      final errors = <DomainException>[
        NotFoundException('Cuenta', 'x'),
        const InvalidInputException('a'),
        const InvalidAmountException(),
        const InvalidTransferException('a'),
        NotACreditCardException('x'),
        const InvalidStatementLinkException('a'),
        const CurrencyMismatchException('a'),
        const DebtMovementCategoryException('a'),
        const CategoryKindMismatchException('a'),
        ArchivedAccountException('x'),
        const InvalidCardScheduleException('a'),
        const DuplicateStatementException('a'),
        const StatementOverlapException('a'),
        DuplicateNameException('a'),
        const DebtNotFullyPaidException('a'),
        DebtClosedException('d', 'forgiven'),
      ];
      for (final e in errors) {
        expect(describeError(e), isNotEmpty, reason: '$e');
      }
    });
  });

  group('errorFieldOf', () {
    test('monto, nombre y categoría', () {
      expect(errorFieldOf(const InvalidAmountException()), ErrorField.amount);
      expect(errorFieldOf(const InvalidInputException('El nombre no puede estar vacío')),
          ErrorField.name);
      expect(errorFieldOf(DuplicateNameException('x')), ErrorField.name);
      expect(errorFieldOf(const CategoryKindMismatchException('a')), ErrorField.category);
    });

    test('transferencias: destino y monto de destino', () {
      expect(errorFieldOf(const InvalidTransferException('Una transferencia requiere cuenta destino')),
          ErrorField.destination);
      expect(
          errorFieldOf(const InvalidTransferException(
              'Las cuentas tienen monedas distintas: indica el monto de destino')),
          ErrorField.transferAmount);
      expect(errorFieldOf(const InvalidTransferException('Las transferencias no llevan categoría')),
          ErrorField.general);
    });

    test('cuenta archivada según sea origen o destino', () {
      expect(
          errorFieldOf(ArchivedAccountException('a'),
              sourceAccountId: 'a', destinationAccountId: 'b'),
          ErrorField.account);
      expect(
          errorFieldOf(ArchivedAccountException('b'),
              sourceAccountId: 'a', destinationAccountId: 'b'),
          ErrorField.destination);
    });

    test('lo demás es general', () {
      expect(errorFieldOf(const CurrencyMismatchException('a')), ErrorField.general);
      expect(errorFieldOf(StateError('x')), ErrorField.general);
    });
  });
}
