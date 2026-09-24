import 'package:flutter/material.dart';

import '../../data/database/app_database.dart';
import '../accounts/account_labels.dart';
import 'tokens.dart';
import 'typography.dart';

/// Fila horizontal de cuentas para elegir una. Cada chip mide al menos 48 dp
/// de alto. Si no caben todas, el borde derecho se desvanece para indicar que
/// se puede desplazar.
///
/// Con [allLabel] se añade una primera opción ("Todas") que deja la selección
/// en `null`, útil en filtros.
class AccountChips extends StatefulWidget {
  const AccountChips({
    super.key,
    required this.accounts,
    required this.selectedId,
    required this.onSelected,
    this.errorText,
    this.allLabel,
  });

  final List<Account> accounts;
  final String? selectedId;
  final ValueChanged<String?> onSelected;
  final String? errorText;
  final String? allLabel;

  @override
  State<AccountChips> createState() => _AccountChipsState();
}

class _AccountChipsState extends State<AccountChips> {
  final _controller = ScrollController();
  bool _moreToTheRight = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_update);
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void didUpdateWidget(AccountChips old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _update() {
    if (!mounted || !_controller.hasClients) return;
    final more = _controller.position.extentAfter > 4;
    if (more != _moreToTheRight) setState(() => _moreToTheRight = more);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final hasAll = widget.allLabel != null;
    final count = widget.accounts.length + (hasAll ? 1 : 0);

    Widget chip({
      required String label,
      required IconData icon,
      required bool selected,
      required VoidCallback onTap,
    }) => Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? c.accentSoft : c.surface,
        shape: StadiumBorder(side: BorderSide(color: selected ? c.accent : c.border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: selected ? c.accent : c.textSecondary),
                const SizedBox(width: Space.sm),
                Text(
                  label,
                  style: t.bodyStrong.copyWith(color: selected ? c.accent : c.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final list = SizedBox(
      height: kMinTap,
      child: ListView.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
        itemBuilder: (context, i) {
          if (hasAll && i == 0) {
            return chip(
              label: widget.allLabel!,
              icon: Icons.layers_outlined,
              selected: widget.selectedId == null,
              onTap: () => widget.onSelected(null),
            );
          }
          final a = widget.accounts[i - (hasAll ? 1 : 0)];
          return chip(
            label: a.name,
            icon: accountTypeIcon(a.type),
            selected: a.id == widget.selectedId,
            onTap: () => widget.onSelected(a.id),
          );
        },
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => LinearGradient(
            colors: _moreToTheRight
                ? const [Colors.white, Colors.white, Colors.transparent]
                : const [Colors.white, Colors.white, Colors.white],
            stops: const [0, 0.86, 1],
          ).createShader(rect),
          child: list,
        ),
        if (widget.errorText != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, 0),
            child: Text(widget.errorText!, style: t.caption.copyWith(color: c.danger)),
          ),
      ],
    );
  }
}
