import 'package:flutter/material.dart';

import 'typography.dart';

/// Barra superior de las pestañas: título grande alineado a la izquierda.
PreferredSizeWidget tabAppBar(
  BuildContext context,
  String title, {
  List<Widget> actions = const [],
}) => AppBar(
  toolbarHeight: 64,
  title: Text(title, style: context.text.title),
  actions: [...actions, const SizedBox(width: 4)],
);
