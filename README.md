# qabal

Gestor de finanzas personales para Android, 100% nativo y offline-first: la base de datos vive en el teléfono, sin backend propio. A futuro, backup opcional en el Google Drive del usuario (`appDataFolder`).

El nombre viene de la expresión guatemalteca «cabal»: el momento en que las cuentas cuadran sin que sobre ni falte un centavo. La **q** es un guiño al Quetzal.

## Qué hace

- **Cuentas y movimientos** en varias monedas: ingresos, gastos y transferencias, con categorías, subcategorías, contactos y etiquetas.
- **Inicio:** saldo total, deuda de tarjetas y neto por moneda, con resumen mensual.
- **Tarjetas de crédito:** límite, día de corte y de pago, ciclo en curso, crédito disponible, estados de cuenta, pagos vinculados y «Próximos pagos».
- **Deudas con personas** *(en camino)*: «te deben» y «debes», abonos, saldar y perdonar.
- **Después:** backup en Google Drive, reportes, presupuestos, movimientos recurrentes, seguridad biométrica/PIN y exportación CSV.

## Stack

| Capa | Tecnología |
|---|---|
| Lenguaje | Kotlin |
| UI | Jetpack Compose, Material 3 |
| Arquitectura | Clean Architecture (`ui` / `domain` / `data`) + MVVM, flujo unidireccional con `StateFlow` |
| Base de datos | Room |
| Inyección de dependencias | Dagger Hilt |
| Navegación | Navigation Compose con rutas type-safe |
| Build | Gradle (Kotlin DSL) con version catalog |
| Pruebas | Pruebas unitarias de dominio y repositorios, con reloj inyectado |

Paquete: `com.draskint.qabal`.

## Identidad

- **Logotipo:** solo el wordmark `qabal`, siempre en minúsculas, sans-serif geométrica en peso Medium/SemiBold. Sin isotipos ni íconos cliché.
- **Tipografía:** Inter. Títulos grandes y pesados; cifras en monoespaciada para alinear los montos.
- **Color:** monocromo. Fondo `#FFFFFF` o `#0A0A0A`; bordes `#E5E5E5` o `#1A1A1A`. Ingresos y gastos se distinguen por opacidad, no por verde y rojo.
- **Estilo:** herramienta técnica. Sin sombras difuminadas, líneas marcadas, espacio negativo amplio y módulos tipo bento grid.

## Estructura

```
app/src/main/kotlin/com/draskint/qabal/
├── di/        módulos de Hilt
├── core/      dinero, formateadores, errores
├── domain/    modelos, interfaces de repositorio, casos de uso
├── data/      Room (entidades, DAOs, convertidores, seed) y repositorios
└── ui/        sistema de diseño, navegación y pantallas por feature
```

## Desarrollo

Requisitos: JDK 17 o superior y Android SDK 36.

```bash
./gradlew assembleDebug        # compila
./gradlew testDebugUnitTest    # pruebas unitarias
```

## Convenciones

Commits atómicos con [Conventional Commits](https://www.conventionalcommits.org/) y la descripción en español: `<tipo>: <descripción en imperativo, minúsculas, sin punto final>`.

## Licencia

Las fuentes Inter en `assets/fonts/` se distribuyen bajo SIL Open Font License (`OFL-Inter.txt`).
