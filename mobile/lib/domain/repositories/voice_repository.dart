import 'dart:typed_data';

abstract class VoiceRepository {
  Stream<dynamic> get voiceStream;
  void connect(); // Removed String serverUrl
  void sendAudio(Uint8List audioChunk);
  void disconnect();
}