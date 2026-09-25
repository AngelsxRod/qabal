import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../design/amount_text.dart';
import '../design/category_avatar.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'account_labels.dart';

/// Fila de una cuenta con su saldo; lleva a su detalle.
class AccountRow extends StatelessWidget {
  const AccountRow(this.item, {super.key});

  final AccountBalance item;

  @override
  Widget build(BuildContext context) {
    final a = item.account;
    final c = context.colors;
    final t = context.text;
    return InkWell(
      onTap: () => context.push(Routes.accountDetail(a.id)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 68),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
          child: Row(
            children: [
              CategoryAvatar(icon: accountTypeIcon(a.type), color: c.accent),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.name, style: t.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(
                      a.isArchived
                          ? '${accountTypeLabel(a.type)} · Archivada'
                          : accountTypeLabel(a.type),
                      style: t.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.md),
              AmountText(
                item.balanceMinor,
                a.currency,
                color: item.balanceMinor < 0 ? c.expense : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
