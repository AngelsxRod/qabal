import 'package:flutter/material.dart';

import '../../domain/errors.dart';
import 'describe_error.dart';

/// Pide un nombre en un diálogo. [onSubmit] guarda el valor; si lanza un error
/// de dominio (nombre vacío, repetido…) el diálogo sigue abierto y lo muestra
/// bajo el campo. Devuelve `true` si se guardó.
Future<bool> showNameDialog(
  BuildContext context, {
  required String title,
  required Future<void> Function(String name) onSubmit,
  String initial = '',
  String confirmLabel = 'Guardar',
}) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) =>
        _NameDialog(title: title, initial: initial, confirmLabel: confirmLabel, onSubmit: onSubmit),
  );
  return saved ?? false;
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.initial,
    required this.confirmLabel,
    required this.onSubmit,
  });

  final String title;
  final String initial;
  final String confirmLabel;
  final Future<void> Function(String name) onSubmit;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_controller.text);
      if (mounted) Navigator.of(context).pop(true);
    } on DomainException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = describeError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: 'Nombre', errorText: _error),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _saving ? null : _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
