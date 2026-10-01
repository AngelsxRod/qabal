# 📈 Progreso del Proyecto: qabal

> Hoja de ruta compartida entre desarrolladores y agentes de IA. **Léela al empezar una sesión y actualízala al terminar** (en el mismo commit o en uno `docs:` aparte). Última actualización: 2026-10-01.

## 🎯 Estado Actual
Reescritura nativa de la app Flutter original como **qabal** (Android, Kotlin, Compose M3, Room, Hilt). Estamos construyendo el esqueleto técnico de abajo hacia arriba (Data → Domain → UI). Hecho: proyecto Gradle, Hilt, enums de dominio, convertidores y entidades de Room con `AppDatabase` v1, DAOs, POJOs de relación, `DatabaseModule`, triggers de integridad y seed de categorías (20 tests con Room en memoria y Robolectric). `core/` (dinero, formateadores y errores de dominio). repositorios de cuentas, movimientos, catálogos (categorías, contactos, etiquetas), deudas y tarjetas (ciclo, estados de cuenta, pendientes), asignación automática del estado al pagar y totales por periodo y categoría (140 tests en total). La capa de datos queda completa. Sistema de diseño base listo. **Objetivo inmediato:** navegación type-safe con barra inferior y botón central `+`.

Los commits van atómicos, en español y sin trailer `Co-Authored-By` (ver `CLAUDE.md` de `Proyectos/personal`).

## 🛠️ Tareas en Progreso (In Progress)
- [ ] **Navegación type-safe** con barra inferior y botón central `+` (ver backlog).

## ✅ Tareas Completadas (Done)
### Hito 1: Esqueleto técnico (en curso desde 2026-10-01)
- [x] `090c7bc` Código legado de Flutter eliminado (sigue en el historial).
- [x] `6f62ef5` Proyecto Gradle Kotlin DSL con version catalog y wrapper (Gradle 9.6.0, AGP 9.4.1, compileSdk/targetSdk 37, minSdk 26).
- [x] `5f308e2` Hilt y KSP, `QabalApp` y `MainActivity` base, `ClockModule` (`java.time.Clock` inyectable).
- [x] `b4ecee8` Rename a qabal; paquete `com.draskint.qabal`.
- [x] `fb1a93e` README con la identidad y el stack.
- [x] `a6368b5` Enums de dominio (`domain/model/Enums.kt`) y `Converters` de Room (`data/local/converter`), con 6 tests.
- [x] Entidades Room (`data/local/entity`: 9 tablas con claves foráneas e índices), `AppDatabase` v1 y schema exportado en `app/schemas`. Room compiler añadido a KSP.
- [x] POJOs de relación (`data/local/relation`), 7 DAOs con `Flow` (`data/local/dao`; agregados de saldo y deuda como sumas, la composición vive en el repositorio) y `DatabaseModule` de Hilt.
- [x] Triggers de integridad (`data/local/trigger`, `BEFORE INSERT/UPDATE` con `RAISE(ABORT)`) para las reglas `CHECK` del Drift; seed idempotente de 20 categorías (`data/local/seed`, ids `system:*` y `default:*`); `DatabaseCallback` los instala. Tests con Room en memoria y Robolectric (`DatabaseTestBase`).
- [x] `core/format`: `Money.kt` (`formatMoney`, `formatSignedMoney`, `formatPlain`, `formatGrouped`, `parseMinor` sobre `Long`), `MoneyInput.kt` (`MoneyInputFormatter` puro, sin Compose, y `parseInputMinor`), `Dates.kt` (español, `LocalDate`). `domain/error/DomainException.kt` sellada. Port de los tests de Dart (35 tests nuevos).
- [x] Dominio de cuentas y movimientos (`domain/model`), ciclo y validación de horario de tarjeta (`domain/card`), mappers (`data/mapper`), `IdGenerator` inyectable, `AccountRepository` (alta con tarjeta atómica, saldos reactivos) y `TransactionRepository` (validación completa del Flutter, filtros dinámicos con `@RawQuery`, etiquetas). Falta lo marcado en el backlog.
- [x] Repositorios de catálogos (`CategoryRepository`, `ContactRepository`, `TagRepository`), deudas (`DebtRepository`: saldo por abonos, saldar, perdonar, reabrir) y tarjetas (`CreditCardRepository` + `LedgerQueries`: resumen del ciclo, estados de cuenta, `pendingStatements`, `suggestStatementForPayment`; `observeComputed` para flujos calculados). `TransactionRepository` asigna el estado de cuenta al pagar una tarjeta (`autoAssignStatement`) y ofrece `totals`/`totalsByCategory`.
- [x] Sistema de diseño (`ui/theme`, `ui/components`, `ui/icons`): Compose + M3 con tema monocromo claro/oscuro, Inter (Regular a Bold) y fuente monoespaciada del sistema para cifras (`QabalData`), tokens de color/forma/espaciado, `BentoCard`, `AmountText` (ingresos 100 % / gastos 50 % de opacidad), `Wordmark` y 5 iconos de trazo propios. `DesignShowcase` con previews; `MainActivity` lo muestra temporalmente.
- [x] Repo publicado: https://github.com/AngelsxRod/qabal (público, rama `main`).

## ⏳ Próximas Tareas (Backlog)
Hito 1, esqueleto técnico (orden propuesto):
- [ ] Navegación type-safe con barra inferior y botón central `+`.

Hitos funcionales (paridad con la app Flutter):
- [ ] **Hito 2:** cuentas y movimientos (CRUD, filtros persistentes), Inicio (saldo total, deuda de tarjetas, neto por moneda, resumen mensual con selector de mes y devoluciones separadas) y catálogos (categorías con subcategorías, contactos, etiquetas, archivar y restaurar).
- [ ] **Hito 3:** tarjetas de crédito (límite, corte, pago, ciclo en curso, crédito disponible, estados de cuenta, pagos vinculados, «Próximos pagos»).
- [ ] **Hito 4 (prioridad alta):** deudas con personas: «te deben» y «debes» por contacto y moneda, formulario, abonos, saldar y perdonar.
- [ ] **Hitos 5 a 9:** backup en Google Drive (`appDataFolder`), reportes y gráficas, presupuestos, movimientos recurrentes, seguridad biométrica/PIN y exportación CSV.

## 📌 Decisiones de arquitectura (no re-litigar)
- Un solo módulo `:app`, paquetes por capa: `di`, `core`, `domain`, `data`, `ui`. Separar en módulos es un paso mecánico posterior.
- IDs `String` UUID v4. Dinero en `Long` de unidades menores (`*Minor`), nunca `Double`. Moneda ISO-4217 de 3 letras en cuentas y deudas; la de un movimiento se deriva de su cuenta.
- Fecha-hora como `Instant` (epoch ms); fecha sin hora como `LocalDate` (`yyyy-MM-dd`); enums por `name`.
- Room no soporta `CHECK`: las invariantes se validan en dominio y repositorio, y las críticas con triggers.
- Los repositorios reciben `Clock` para fijar el tiempo en tests. Estado con `StateFlow` inmutable.
- **Esquema de referencia:** el Drift original está en el historial. Ejemplo: `git show 090c7bc^:lib/data/database/tables/transactions.dart`. Lo mismo vale para `seed.dart` y `lib/domain/credit_card/`.
- Los triggers de integridad se reinstalan en cada apertura (`DatabaseCallback.onOpen`): cambiar una regla en `IntegrityTriggers` basta, sin tocar migraciones.
- Al agregar un plugin de Gradle (Compose, serialization...), comprobar que su versión sea compatible con AGP 9.4.1 (Kotlin integrado 2.3.x) y KSP 2.3.12.
- Los textos y el campo de formulario de cada `DomainException` viven en `ui/error/ErrorMessages.kt` (`describeError`, `errorFieldOf`, `when` exhaustivo).
- Identidad: wordmark `qabal` en minúsculas, Inter, monocromo (`#FFFFFF`/`#0A0A0A`, bordes `#E5E5E5`/`#1A1A1A`), ingresos y gastos por opacidad, sin íconos cliché ni sombras difuminadas.

## ⚠️ Problemas Conocidos / Bloqueos (Blockers)
- 🟢 Sin bloqueos.

## 🧰 Comandos útiles
```bash
./gradlew assembleDebug        # compila
./gradlew testDebugUnitTest    # pruebas unitarias
./gradlew clean assembleDebug  # build limpio (obligatorio tras renombrar paquetes o clases: el incremental falla con código generado viejo)
```
