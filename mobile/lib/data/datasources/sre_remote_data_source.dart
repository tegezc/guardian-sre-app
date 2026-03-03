import 'dart:async';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:injectable/injectable.dart';

abstract class SreRemoteDataSource {
  Stream<dynamic> get liveStream;
  void connect(); // URL is no longer needed as a parameter
  void sendAudio(Uint8List audioChunk);
  void closeConnection();
}

@LazySingleton(as: SreRemoteDataSource)
class SreRemoteDataSourceImpl implements SreRemoteDataSource {
  final String serverUrl;
  WebSocketChannel? _channel;

  /// Broadcast controller allows multiple listeners without throwing state errors.
  final StreamController<dynamic> _streamController = StreamController<dynamic>.broadcast();

  /// Injecting the baseUrl using the named dependency from RegisterModule.
  SreRemoteDataSourceImpl(@Named("baseUrl") this.serverUrl);

  @override
  Stream<dynamic> get liveStream => _streamController.stream;

  @override
  void connect() {
    try {
      // Establish WebSocket connection using the injected serverUrl
      _channel = WebSocketChannel.connect(Uri.parse('$serverUrl/ws/live'));

      // Pipe data from WebSocket into our internal broadcast stream
      _channel!.stream.listen(
            (message) {
          _streamController.add(message);
        },
        onError: (error) {
          _streamController.addError(error);
        },
        onDone: () {
          // Handle unexpected server disconnects
          if (!_streamController.isClosed) {
            _streamController.addError("Connection closed by server.");
          }
        },
      );
    } catch (e) {
      if (!_streamController.isClosed) {
        _streamController.addError(e);
      }
    }
  }

  @override
  void sendAudio(Uint8List audioChunk) {
    // Ensure the sink is available before pumping data
    if (_channel != null && _channel?.closeCode == null) {
      _channel!.sink.add(audioChunk);
    }
  }

  @override
  void closeConnection() {
    _channel?.sink.close();
    _channel = null;
  }
}