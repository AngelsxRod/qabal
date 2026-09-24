import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

/// Fila tocable que muestra un valor y abre un selector (categoría, fecha,
/// contacto…). Muestra su [errorText] justo debajo.
class PickerRow extends StatelessWidget {
  const PickerRow({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.leading,
    this.placeholder = false,
    this.errorText,
    this.trailing,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final Widget? leading;

  /// `true` cuando [value] es un texto de invitación ("Elegir…"), no un valor.
  final bool placeholder;
  final String? errorText;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: '$label: $value',
          excludeSemantics: true,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
                child: Row(
                  children: [
                    if (leading != null) ...[leading!, const SizedBox(width: Space.md)],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(label, style: t.label),
                          Text(
                            value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.bodyStrong.copyWith(
                              color: placeholder ? c.textTertiary : c.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    trailing ?? Icon(Icons.chevron_right_rounded, color: c.textTertiary),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm),
            child: Text(errorText!, style: t.caption.copyWith(color: c.danger)),
          ),
      ],
    );
  }
}
