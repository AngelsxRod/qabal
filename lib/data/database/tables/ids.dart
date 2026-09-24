import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Genera un identificador UUID v4 para registros nuevos.
String newId() => _uuid.v4();
