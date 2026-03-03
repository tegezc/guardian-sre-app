import 'dart:typed_data';
import 'package:injectable/injectable.dart';
import '../repositories/voice_repository.dart';

/// Use case responsible for forwarding captured audio bytes to the backend.
@lazySingleton
class SendAudioChunkUseCase {
  final VoiceRepository _repository;

  SendAudioChunkUseCase(this._repository);

  void execute(Uint8List audioChunk) {
    _repository.sendAudio(audioChunk);
  }
}