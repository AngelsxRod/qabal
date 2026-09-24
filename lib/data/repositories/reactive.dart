import 'dart:async';

import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// Stream que recalcula `compute` cada vez que cambia alguna de `tables`.
///
/// Emite al escuchar y después de cada escritura confirmada. Si llegan
/// cambios mientras se recalcula, se vuelve a calcular al terminar, así que
/// el último valor emitido siempre refleja el último estado.
Stream<T> watchComputed<T>(
  AppDatabase db,
  Iterable<ResultSetImplementation<dynamic, dynamic>> tables,
  Future<T> Function() compute,
) {
  late final StreamController<T> controller;
  StreamSubscription<Set<TableUpdate>>? subscription;
  var running = false;
  var dirty = false;

  Future<void> run() async {
    if (running) {
      dirty = true;
      return;
    }
    running = true;
    try {
      do {
        dirty = false;
        final value = await compute();
        if (!controller.isClosed) controller.add(value);
      } while (dirty);
    } catch (e, s) {
      if (!controller.isClosed) controller.addError(e, s);
    } finally {
      running = false;
    }
  }

  controller = StreamController<T>(
    onListen: () {
      subscription = db
          .tableUpdates(TableUpdateQuery.onAllTables(tables))
          .listen((_) => run());
      run();
    },
    onCancel: () => subscription?.cancel(),
  );
  return controller.stream;
}
