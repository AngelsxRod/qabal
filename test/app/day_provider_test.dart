import 'package:finanzas/app/providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_env.dart';

void main() {
  late FakeClock clock;
  late ProviderContainer container;

  ProviderContainer makeContainer(DateTime start) {
    clock = FakeClock(start);
    return ProviderContainer(
      overrides: [nowProvider.overrideWithValue(clock.call)],
    );
  }

  /// El chequeo de timers pendientes de `testWidgets` corre antes de los
  /// `tearDown`, así que el contenedor se libera dentro del propio test.
  void dayTest(
    String name,
    DateTime start,
    Future<void> Function(WidgetTester) body,
  ) {
    testWidgets(name, (tester) async {
      container = makeContainer(start);
      try {
        await body(tester);
      } finally {
        container.dispose();
      }
    });
  }

  dayTest(
    'parte con la fecha de hoy a medianoche',
    DateTime(2026, 9, 24, 15, 30),
    (tester) async {
      expect(container.read(dayProvider), DateTime(2026, 9, 24));
    },
  );

  dayTest(
    'cambia a la medianoche local sin que la app haga nada',
    DateTime(2026, 9, 24, 23, 0),
    (tester) async {
      final seen = <DateTime>[];
      container.listen(dayProvider, (_, next) => seen.add(next));
      expect(container.read(dayProvider), DateTime(2026, 9, 24));

      // Antes de la medianoche no pasa nada.
      clock.current = DateTime(2026, 9, 24, 23, 59);
      await tester.pump(const Duration(minutes: 59));
      expect(seen, isEmpty);

      // Pasa la medianoche: el temporizador refresca el día.
      clock.current = DateTime(2026, 9, 25, 0, 0, 1);
      await tester.pump(const Duration(minutes: 2));
      expect(seen, [DateTime(2026, 9, 25)]);
      expect(container.read(dayProvider), DateTime(2026, 9, 25));

      // Y queda programado para la siguiente medianoche.
      clock.current = DateTime(2026, 9, 26, 0, 0, 1);
      await tester.pump(const Duration(hours: 24));
      expect(container.read(dayProvider), DateTime(2026, 9, 26));
    },
  );

  dayTest(
    'al volver a primer plano se pone al día',
    DateTime(2026, 9, 24, 22),
    (tester) async {
      final seen = <DateTime>[];
      container.listen(dayProvider, (_, next) => seen.add(next));

      // El sistema suspendió la app: pasó un día y el temporizador no corrió.
      clock.current = DateTime(2026, 9, 25, 8);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(container.read(dayProvider), DateTime(2026, 9, 25));
      expect(seen, [DateTime(2026, 9, 25)]);

      // Si sigue siendo el mismo día, no notifica de nuevo.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(seen, hasLength(1));
    },
  );

  dayTest(
    'los providers que observan el día se recalculan al cambiar',
    DateTime(2026, 9, 24, 23, 59),
    (tester) async {
      final label = Provider((ref) {
        final d = ref.watch(dayProvider);
        return '${d.year}-${d.month}-${d.day}';
      });
      final seen = <String>[];
      container.listen(
        label,
        (_, next) => seen.add(next),
        fireImmediately: true,
      );
      clock.current = DateTime(2026, 9, 25, 0, 0, 1);
      await tester.pump(const Duration(minutes: 2));
      expect(seen, ['2026-9-24', '2026-9-25']);
    },
  );
}
