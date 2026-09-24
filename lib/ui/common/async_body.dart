import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'describe_error.dart';

/// Resuelve un `AsyncValue` con indicador de carga y mensaje de error.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({super.key, required this.value, required this.data});

  final AsyncValue<T> value;
  final Widget Function(T data) data;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(describeError(error), textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
