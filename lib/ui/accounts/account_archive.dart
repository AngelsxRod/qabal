import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../common/confirm_dialog.dart';
import '../common/describe_error.dart';

/// Archiva (con confirmación) o restaura una cuenta o tarjeta.
Future<void> setAccountArchived(
  BuildContext context,
  WidgetRef ref,
  String accountId,
  bool archived,
) async {
  if (archived) {
    final ok = await confirmAction(
      context,
      title: 'Archivar cuenta',
      message:
          'La cuenta dejará de ofrecerse para nuevos movimientos, pero conserva su '
          'historial y puedes restaurarla cuando quieras.',
      confirmLabel: 'Archivar',
    );
    if (!ok || !context.mounted) return;
  }
  try {
    await ref.read(accountRepositoryProvider).update(accountId, isArchived: archived);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }
}
