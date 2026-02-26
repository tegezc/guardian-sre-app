import 'dart:typed_data';
import '../entities/sre_message.dart';

/// Contract for SRE data operations. 
/// Defined in Domain, implemented in Data layer.
abstract class SreRepository {
  Stream<SreMessage> getSreStream();
  Future<void> sendVoiceCommand(Uint8List audio);
  void stopSession();
}