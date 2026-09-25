/// Las categorías del sistema (`system:*`) las usa la lógica de tarjetas y de
/// totales por id: no se renombran, no se archivan ni admiten subcategorías
/// (una hija de "Devoluciones" contaría como ingreso normal).
bool isSystemCategory(String id) => id.startsWith('system:');
