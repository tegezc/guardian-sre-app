import 'package:injectable/injectable.dart';
import '../repositories/voice_repository.dart';

/// Use case responsible for performing cleanup and closing connections.
@lazySingleton
class DisconnectVoiceStreamUseCase {
  final VoiceRepository _repository;

  DisconnectVoiceStreamUseCase(this._repository);

  void execute() {
    _repository.disconnect();
  }
}