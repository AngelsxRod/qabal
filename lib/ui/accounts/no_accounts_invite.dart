import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';

/// Primer arranque: en lugar de una pantalla vacía, invita a crear la primera
/// cuenta.
class NoAccountsInvite extends StatelessWidget {
  const NoAccountsInvite({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Aún no tienes cuentas', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Crea tu primera cuenta (efectivo, banco…) para empezar a registrar '
              'tus movimientos.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push(Routes.accountNew),
              icon: const Icon(Icons.add),
              label: const Text('Crear mi primera cuenta'),
            ),
          ],
        ),
      ),
    );
  }
}
