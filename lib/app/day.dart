import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/clock.dart';
import 'providers.dart';

/// Fecha de hoy (a medianoche, hora local).
///
/// Se refresca sola cuando cambia el día: con un temporizador a la medianoche
/// local y al volver la app a primer plano (el temporizador no corre si el
/// sistema la suspendió). Los providers que dependen de "hoy" deben observar
/// este provider, no llamar a `DateTime.now()`.
final dayProvider = NotifierProvider<DayNotifier, DateTime>(DayNotifier.new);

class DayNotifier extends Notifier<DateTime> with WidgetsBindingObserver {
  Timer? _timer;

  @override
  DateTime build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _timer?.cancel();
    });
    final now = ref.read(nowProvider)();
    _scheduleMidnight(now);
    return dateOnly(now);
  }

  void _scheduleMidnight(DateTime now) {
    _timer?.cancel();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _timer = Timer(nextMidnight.difference(now), _refresh);
  }

  void _refresh() {
    final now = ref.read(nowProvider)();
    _scheduleMidnight(now);
    // Igual que antes → los observadores no se reconstruyen.
    state = dateOnly(now);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }
}
