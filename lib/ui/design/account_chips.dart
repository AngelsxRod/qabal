import 'package:flutter/material.dart';

import '../../data/database/app_database.dart';
import '../accounts/account_labels.dart';
import 'tokens.dart';
import 'typography.dart';

/// Fila horizontal de cuentas para elegir una. Cada chip mide al menos 48 dp
/// de alto.
class AccountChips extends StatelessWidget {
  const AccountChips({
    super.key,
    required this.accounts,
    required this.selectedId,
    required this.onSelected,
    this.errorText,
  });

  final List<Account> accounts;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: kMinTap,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            itemCount: accounts.length,
            separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
            itemBuilder: (context, i) {
              final a = accounts[i];
              final selected = a.id == selectedId;
              return Semantics(
                button: true,
                selected: selected,
                label: a.name,
                excludeSemantics: true,
                child: Material(
                  color: selected ? c.accentSoft : c.surface,
                  shape: StadiumBorder(side: BorderSide(color: selected ? c.accent : c.border)),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => onSelected(a.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            accountTypeIcon(a.type),
                            size: 18,
                            color: selected ? c.accent : c.textSecondary,
                          ),
                          const SizedBox(width: Space.sm),
                          Text(
                            a.name,
                            style: t.bodyStrong.copyWith(
                              color: selected ? c.accent : c.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, 0),
            child: Text(errorText!, style: t.caption.copyWith(color: c.danger)),
          ),
      ],
    );
  }
}
