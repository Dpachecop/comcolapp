import 'package:equatable/equatable.dart';

/// Errores de dominio de la aplicación.
///
/// Implementa [Exception] para poder lanzarse desde las capas de datos y
/// capturarse tipado en los blocs (`on Failure catch (f)`). Al ser `sealed`,
/// un `switch` sobre un [Failure] es verificado de forma exhaustiva por el
/// compilador: si se agrega un caso nuevo, los `switch` existentes dejan de
/// compilar hasta contemplarlo.
sealed class Failure extends Equatable implements Exception {
  const Failure(this.message);

  /// Mensaje apto para mostrarse al usuario.
  final String message;

  @override
  List<Object?> get props => [message];

  @override
  String toString() => '$runtimeType: $message';
}

/// El modelo `.tflite` o el archivo de etiquetas no se pudo cargar.
class ModelLoadFailure extends Failure {
  const ModelLoadFailure([super.message = 'No se pudo cargar el modelo de detección.']);
}

/// La inferencia falló para un frame concreto.
class InferenceFailure extends Failure {
  const InferenceFailure([super.message = 'No se pudo analizar la imagen.']);
}

/// No hay cámaras disponibles en el dispositivo.
class NoCameraAvailableFailure extends Failure {
  const NoCameraAvailableFailure([super.message = 'No se encontró ninguna cámara disponible.']);
}

/// El usuario negó el permiso de cámara.
class CameraPermissionFailure extends Failure {
  const CameraPermissionFailure([
    super.message = 'Se necesita permiso de cámara para reconocer alimentos.',
  ]);
}

/// La cámara falló por una razón distinta a los permisos.
class CameraFailure extends Failure {
  const CameraFailure([super.message = 'No se pudo iniciar la cámara.']);
}

/// Error no contemplado; envuelve cualquier excepción inesperada.
class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Ocurrió un error inesperado.']);
}
