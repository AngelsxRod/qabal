import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../cards/card_detail_screen.dart';
import 'account_detail_screen.dart';

/// Detalle de una cuenta: el de tarjeta si lo es, el común en otro caso.
class AccountEntryScreen extends ConsumerWidget {
  const AccountEntryScreen({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(accountBalanceProvider(accountId));
    final type = balance.value?.account.type;
    if (type == null) {
      return Scaffold(
        appBar: AppBar(),
        body: balance.hasError
            ? const Center(child: Text('Esta cuenta ya no existe.'))
            : const Center(child: CircularProgressIndicator()),
      );
    }
    return type == AccountType.creditCard
        ? CardDetailScreen(cardId: accountId)
        : AccountDetailScreen(accountId: accountId);
  }
}
