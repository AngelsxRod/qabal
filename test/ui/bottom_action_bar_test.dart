import 'package:finanzas/ui/design/bottom_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sube con el teclado para que el botón quede a la vista', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(children: const [SizedBox(height: 2000)]),
          bottomNavigationBar: BottomActionBar(
            child: FilledButton(onPressed: () {}, child: const Text('Guardar')),
          ),
        ),
      ),
    );

    // El teclado ocupa de y = 500 hacia abajo.
    expect(tester.getBottomLeft(find.byType(FilledButton)).dy, lessThanOrEqualTo(500));
  });
}
