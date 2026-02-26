import 'dart:convert';
import 'dart:typed_data';
import '../../domain/entities/sre_message.dart';

class SreMessageModel extends SreMessage {
  SreMessageModel({
    Uint8List? audioChunk,
    String? textResponse,
    Map<String, dynamic>? metadata,
  }) : super(
          audioChunk: audioChunk,
          textResponse: textResponse,
          metadata: metadata,
        );

  /// Factory to handle dynamic data from the WebSocket.
  /// It could be binary (audio) or a string (JSON metadata/text).
  factory SreMessageModel.fromRawData(dynamic data) {
    if (data is Uint8List) {
      return SreMessageModel(audioChunk: data);
    } else if (data is String) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(data);
        return SreMessageModel(
          textResponse: decoded['text'],
          metadata: decoded['metadata'],
        );
      } catch (e) {
        return SreMessageModel(textResponse: data);
      }
    }
    return SreMessageModel();
  }
}