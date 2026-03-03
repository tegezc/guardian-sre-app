import 'package:injectable/injectable.dart';
import '../repositories/voice_repository.dart';

@lazySingleton
class ConnectVoiceStreamUseCase {
  final VoiceRepository _repository;

  ConnectVoiceStreamUseCase(this._repository);

  Stream<dynamic> execute() {
    _repository.connect(); // No arguments needed
    return _repository.voiceStream;
  }
}