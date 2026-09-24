import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../accounts/account_labels.dart';
import '../accounts/no_accounts_invite.dart';
import '../common/async_body.dart';

/// Pantalla de inicio. Por ahora solo cubre el primer arranque (invita a
/// crear la primera cuenta); el resumen llega en la fase siguiente.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Inicio')),
      body: AsyncBody(
        value: ref.watch(accountBalancesProvider(true)),
        data: (all) => all.any((b) => isPlainAccount(b.account))
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.home_outlined, size: 56, color: theme.colorScheme.outline),
                    const SizedBox(height: 12),
                    Text('Próximamente', style: theme.textTheme.titleMedium),
                  ],
                ),
              )
            : const NoAccountsInvite(),
      ),
    );
  }
}
