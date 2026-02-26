/// SRE Remote Data Source
/// This class handles the WebSocket connection to the Python backend.
/// It sends raw audio bytes and listens for model responses (Audio + Metadata).

import 'dart:async' show Stream;
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:injectable/injectable.dart';

abstract class SreRemoteDataSource {
  Stream<dynamic> get liveStream;
  void sendAudio(Uint8List audioChunk);
  void closeConnection();
}

@Singleton()
class SreRemoteDataSourceImpl implements SreRemoteDataSource {
  final String serverUrl;
  WebSocketChannel? _channel;

  SreRemoteDataSourceImpl({required this.serverUrl});

  @override
  Stream<dynamic> get liveStream {
    // Connect to the FastAPI endpoint created in Step 5
    _channel = WebSocketChannel.connect(Uri.parse('$serverUrl/ws/live'));
    return _channel!.stream;
  }

  @override
  void sendAudio(Uint8List audioChunk) {
    // Send raw audio bytes captured from microphone to Gemini Live API
    if (_channel != null) {
      _channel!.sink.add(audioChunk);
    }
  }

  @override
  void closeConnection() {
    _channel?.sink.close();
  }
}