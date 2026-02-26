import 'dart:typed_data';

/// Entity representing the interaction with the SRE Agent.
/// It can contain audio data, text logs, or infrastructure metrics.
class SreMessage {
  final Uint8List? audioChunk;
  final String? textResponse;
  final Map<String, dynamic>? metadata; // For reactive UI dashboard data

  SreMessage({
    this.audioChunk,
    this.textResponse,
    this.metadata,
  });
}