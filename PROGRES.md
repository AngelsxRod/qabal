# 📈 Progreso del Proyecto: qabal

> Hoja de ruta compartida entre desarrolladores y agentes de IA. **Léela al empezar una sesión y actualízala al terminar** (en el mismo commit o en uno `docs:` aparte). Última actualización: 2026-10-01.

## 🎯 Estado Actual
Reescritura nativa de la app Flutter original como **qabal** (Android, Kotlin, Compose M3, Room, Hilt). Estamos construyendo el esqueleto técnico de abajo hacia arriba (Data → Domain → UI). Hecho: proyecto Gradle, Hilt, enums de dominio y convertidores de Room. **Objetivo inmediato:** commit 5, entidades Room y `AppDatabase` v1.

Los commits van atómicos, en español y sin trailer `Co-Authored-By` (ver `CLAUDE.md` de `Proyectos/personal`).

## 🛠️ Tareas en Progreso (In Progress)
- [ ] **Room / entidades (commit 5):** `AccountEntity`, `CategoryEntity`, `ContactEntity`, `TagEntity`, `CreditCardDetailsEntity`, `CreditCardStatementEntity`, `DebtEntity`, `TransactionEntity`, `TransactionTagCrossRef` y `AppDatabase` v1, con claves foráneas, índices y export del schema. Añade el compilador de Room a KSP.

## ✅ Tareas Completadas (Done)
### Hito 1: Esqueleto técnico (en curso desde 2026-10-01)
- [x] `090c7bc` Código legado de Flutter eliminado (sigue en el historial).
- [x] `6f62ef5` Proyecto Gradle Kotlin DSL con version catalog y wrapper (Gradle 9.3.1, AGP 9.1.0, compileSdk/targetSdk 36, minSdk 26).
- [x] `5f308e2` Hilt y KSP, `QabalApp` y `MainActivity` base, `ClockModule` (`java.time.Clock` inyectable).
- [x] `b4ecee8` Rename a qabal; paquete `com.draskint.qabal`.
- [x] `fb1a93e` README con la identidad y el stack.
- [x] `a6368b5` Enums de dominio (`domain/model/Enums.kt`) y `Converters` de Room (`data/local/converter`), con 6 tests.
- [x] Repo publicado: https://github.com/AngelsxRod/qabal (público, rama `main`).

## ⏳ Próximas Tareas (Backlog)
Hito 1, esqueleto técnico (orden propuesto):
- [ ] Entidades Room y `AppDatabase` v1 (commit 5).
- [ ] DAOs y POJOs de relación: `TransactionWithDetails`, `AccountWithCard`, `CategoryWithChildren`, `DebtWithContact`.
- [ ] Triggers SQL que refuerzan las invariantes de `TransactionEntity` y seed idempotente de categorías.
- [ ] `core/`: dinero en unidades menores, formateadores de monto (miles en vivo) y de fecha, errores de dominio.
- [ ] Modelos de dominio, mappers y repositorios con reglas de negocio (saldos, ingresos, gastos, transferencias, validaciones).
- [ ] Sistema de diseño de qabal: tokens, Inter, tema claro y oscuro, iconos propios.
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
- Identidad: wordmark `qabal` en minúsculas, Inter, monocromo (`#FFFFFF`/`#0A0A0A`, bordes `#E5E5E5`/`#1A1A1A`), ingresos y gastos por opacidad, sin íconos cliché ni sombras difuminadas.

## ⚠️ Problemas Conocidos / Bloqueos (Blockers)
- 🟡 Room no tiene `CHECK`: hay que diseñar bien los triggers y probarlos con Room in-memory (commit de triggers).
- 🟡 AGP 9 trae Kotlin integrado: si se agrega un plugin nuevo (Compose, serialization), comprobar que su versión es compatible con AGP 9.1.0 y KSP 2.3.12.
- 🟡 Tras renombrar paquetes o clases, el build incremental falla con código generado viejo: usar `./gradlew clean assembleDebug`.
- 🟢 Sin bloqueos externos.

## 🧰 Comandos útiles
```bash
./gradlew assembleDebug        # compila
./gradlew testDebugUnitTest    # pruebas unitarias
./gradlew clean assembleDebug  # build limpio
```
