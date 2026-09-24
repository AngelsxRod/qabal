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
- `lib/app/`: arranque de la app: providers de Riverpod (base de datos, repositorios, reloj y `dayProvider`, que se refresca a medianoche y al volver a primer plano), tema claro/oscuro (Material 3) y rutas de `go_router` con la barra inferior de 5 pestañas.
- `lib/core/format/`: formateadores propios sin `intl` (`formatMoney`, `formatDate`, `formatPlain`) y `parseMinor`, que lee montos escritos con punto o coma decimal y rechaza los ambiguos (`1,234`).
- `lib/ui/`: pantallas por área (`accounts/`, `transactions/`, `home/`, `shell/`) y widgets comunes (`common/`, incluido `describeError`, que traduce los errores de dominio a texto y decide en qué campo del formulario se muestran).
- `test/`: pruebas de dominio, de esquema, de repositorios (base en memoria y reloj falso), de formateadores y de widgets (`test/ui/`, con `pumpApp` en `test/support/`).

## Interfaz

- Estado con `flutter_riverpod` (sin generación de código). Las lecturas son `StreamProvider` sobre los `watch...` de los repositorios; las escrituras se llaman directo con `ref.read(...)`. No hay reintentos automáticos de Riverpod: un error de dominio no se arregla repitiendo.
- Los filtros de la pestaña Movimientos viajan como parámetros de la URL (`/movimientos?cuenta=…&tipo=…&desde=2026-09-01&hasta=2026-09-30`); `hasta` es inclusivo.
- Solo español (`es_GT`), con los textos en el código.
- Las tarjetas de crédito todavía no se pueden crear desde la interfaz: aparecen en el selector de tipo como "Próximamente" y las pantallas de cuentas y movimientos las dejan fuera.
- El emulador de desarrollo mide 320 dp de ancho: las etiquetas de la barra inferior y del selector de tipo de movimiento están ajustadas para caber ahí. Los tests de widget usan una fuente sin métricas reales, así que eso solo se comprueba a ojo en el emulador.
