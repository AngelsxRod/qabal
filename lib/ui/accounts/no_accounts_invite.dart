import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../design/empty_state.dart';

/// Primer arranque: en lugar de una pantalla vacía, invita a crear la primera
/// cuenta.
class NoAccountsInvite extends StatelessWidget {
  const NoAccountsInvite({super.key});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.account_balance_wallet_rounded,
      title: 'Aún no tienes cuentas',
      message:
          'Crea tu primera cuenta (efectivo, banco…) para empezar a registrar tus movimientos.',
      actionLabel: 'Crear mi primera cuenta',
      onAction: () => context.push(Routes.accountNew),
    );
  }
}
