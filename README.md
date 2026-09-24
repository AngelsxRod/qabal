# Gestor de finanzas personales

App Android de finanzas personales, offline-first: la base de datos vive en el teléfono (Drift/SQLite), sin backend propio. A futuro, backup opcional en el Google Drive del usuario (appDataFolder).

## Requisitos

- Flutter estable (probado con 3.47.5) y Android SDK con licencias aceptadas.
- `flutter doctor -v` sin errores.

## Puesta en marcha

Los archivos generados (`*.g.dart`) no se versionan; hay que generarlos tras clonar y cada vez que cambien las tablas de Drift:

```bash
flutter pub get
dart run build_runner build
flutter run
```

## Comandos útiles

```bash
flutter analyze
flutter test
flutter build apk --debug
```

## Estructura

- `lib/data/database/`: base de datos Drift (tablas en `tables/`) y sembrado de categorías (`seed.dart`).
- `lib/data/repositories/`: repositorios con las reglas de negocio, validaciones y cálculos (saldos, ciclos de tarjeta, deudas, totales). Ofrecen versiones reactivas (`watch...`) y reciben un reloj inyectable (`Now`).
- `lib/domain/`: errores de dominio (`errors.dart`), reloj y lógica pura de ciclos y estados de cuenta de tarjeta.
- `test/`: pruebas de dominio, de esquema y de repositorios (base en memoria y reloj falso).
