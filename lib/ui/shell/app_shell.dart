import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../design/app_bottom_bar.dart';

/// Marco con la barra inferior: cuatro destinos y el botón central "+" para
/// registrar un movimiento. Cada destino conserva su propia pila.
///
/// La pestaña de movimientos se llama "Historial" en la barra: "Movimientos"
/// no cabe a 12 sp en 320 dp (mide 73 dp y el hueco es de 65). El título de
/// la pantalla sigue siendo "Movimientos".
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _items = [
    BottomBarItem(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Inicio'),
    BottomBarItem(
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
      label: 'Historial',
    ),
    BottomBarItem(
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet_rounded,
      label: 'Cuentas',
    ),
    BottomBarItem(
      icon: Icons.more_horiz_rounded,
      selectedIcon: Icons.more_horiz_rounded,
      label: 'Más',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: AppBottomBar(
        items: _items,
        currentIndex: navigationShell.currentIndex,
        onSelected: (i) =>
            // Tocar la pestaña activa vuelve a su raíz.
            navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex),
        onAction: () => context.push(Routes.transactionNew),
      ),
    );
  }
}
