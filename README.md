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
- `lib/ui/design/`: sistema de diseño propio (sin librerías de componentes): tokens de color, espaciado y radios, tipografía Inter empaquetada en `assets/fonts/` (con cifras tabulares para montos), tema claro/oscuro y componentes reutilizables (monto con separador de miles en vivo, chips de cuenta, selector de categoría, filas de movimiento, barra inferior con botón central, estados vacíos). En debug, "Más → Galería de componentes" los muestra todos en claro y oscuro.
- `lib/ui/`: pantallas por área (`accounts/`, `transactions/`, `home/`, `categories/`, `catalog/` (contactos y etiquetas), `more/`, `shell/`) y widgets comunes (`common/`, incluido `describeError`, que traduce los errores de dominio a texto y decide en qué campo del formulario se muestran).
- `test/`: pruebas de dominio, de esquema, de repositorios (base en memoria y reloj falso), de formateadores y de widgets (`test/ui/`, con `pumpApp` en `test/support/`).

## Interfaz

- Estado con `flutter_riverpod` (sin generación de código). Las lecturas son `StreamProvider` sobre los `watch...` de los repositorios; las escrituras se llaman directo con `ref.read(...)`. No hay reintentos automáticos de Riverpod: un error de dominio no se arregla repitiendo.
- Los filtros de la pestaña Movimientos viajan como parámetros de la URL (`/movimientos?cuenta=…&tipo=…&desde=2026-09-01&hasta=2026-09-30`); `hasta` es inclusivo.
- Solo español (`es_GT`), con los textos en el código.
- Navegación: Inicio · Historial · (+) · Cuentas · Más. La pestaña se llama "Historial" porque "Movimientos" no cabe a 12 sp en 320 dp; el título de la pantalla sigue siendo "Movimientos". Deudas vivirá dentro de Más.
- Inicio muestra, por moneda, el saldo total (cuentas activas que no son tarjeta), la deuda de tarjetas y el neto; los ingresos y gastos netos del mes elegido (con selector de mes y las devoluciones aparte); y las cuentas con su saldo. "Próximos pagos" (tarjetas) y "Te deben / Debes" (deudas) tienen su espacio reservado en `home/reserved_section.dart`, oculto hasta esas fases.
- Más → Categorías, Contactos y Etiquetas: se crean, renombran y archivan (los archivados se ocultan, con opción para verlos y restaurarlos). Las categorías tienen un nivel de subcategorías, ícono y color. Las del sistema (`system:*`) no se renombran ni se archivan ni admiten subcategorías (la lógica de totales y tarjetas las identifica por id). Archivar una categoría archiva también sus subcategorías. Los archivados no se ofrecen en el formulario de movimiento, pero un movimiento que ya los usa los sigue mostrando.
- Las tarjetas de crédito todavía no se pueden crear desde la interfaz: aparecen en el selector de tipo como "Próximamente" y las pantallas de cuentas y movimientos las dejan fuera.
- El emulador de desarrollo mide 320 dp de ancho: las etiquetas de la barra inferior y del selector de tipo de movimiento están ajustadas para caber ahí. Los tests de widget usan una fuente sin métricas reales (Ahem), así que eso solo se comprueba a ojo en el emulador.

## Formato

`dart format` usa 100 columnas (`formatter: page_width: 100` en `analysis_options.yaml`).
