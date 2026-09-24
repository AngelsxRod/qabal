/// Reloj inyectable: los repositorios lo usan para `createdAt`/`updatedAt` y
/// para todo lo que dependa de "hoy", de modo que las pruebas lo controlen.
typedef Now = DateTime Function();

/// Fecha de calendario (medianoche local) de `d`.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
