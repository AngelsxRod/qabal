import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'data/database/app_database.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  runApp(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      // Sin reintentos automáticos: un error de dominio no se arregla
      // repitiendo la operación, solo se retrasaría el aviso al usuario.
      retry: (retryCount, error) => null,
      child: const FinanzasApp(),
    ),
  );
}
