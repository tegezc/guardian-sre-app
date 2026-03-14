import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:injectable/injectable.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

abstract class SreRemoteDataSource {
  Stream<dynamic> get liveStream;
  void connect();
  void sendAudio(Uint8List audioChunk);
  void closeConnection();
}

@LazySingleton(as: SreRemoteDataSource)
class SreRemoteDataSourceImpl implements SreRemoteDataSource {
  final String serverUrl;
  IO.Socket? _socket;

  /// Broadcast controller allows multiple listeners without throwing state errors.
  final StreamController<dynamic> _streamController = StreamController<dynamic>.broadcast();

  /// Injecting the baseUrl using the named dependency from RegisterModule.
  SreRemoteDataSourceImpl(@Named("baseUrl") this.serverUrl);

  @override
  Stream<dynamic> get liveStream => _streamController.stream;

  @override
  void connect() {
    try {
      // 1. Initialize Socket.IO with anti-disconnect configuration
      _socket = IO.io(serverUrl, IO.OptionBuilder()
          .setTransports(['websocket']) // Force using websocket path for real-time
          .disableAutoConnect()
          .build());

      // 2. Handle Connection Events
      _socket!.onConnect((_) {
        print(' SreRemoteDataSource: Connected to Socket.IO Server');
        // Must trigger backend to start Gemini Live session
        _socket!.emit('start_session');
      });

      // 3. Handle Text/Status Events (Optional, if backend sends logs)
      _socket!.on('system_status', (data) {
        if (!_streamController.isClosed) {
          // Forward status message as string to BLoC
          _streamController.add(data['message']);
        }
      });

      // ==========================================================
      // 🌟 3.5 Handle SRE HUD Metrics Event
      // ==========================================================
      _socket!.on('ui_update', (data) {
        if (!_streamController.isClosed) {
          print(' Receiving SRE Metrics Data from Backend: $data');
          // Send this raw JSON Map into the BLoC pipe
          _streamController.add(data);
        }
      });
      // ==========================================================

      // 4. Handle Audio Event from Gemini
      _socket!.on('audio_response', (data) {
        if (data != null && data['audio'] != null) {
          // Clean Architecture: Hide Base64 complexity from BLoC.
          // We decode here so BLoC still receives Uint8List as before.
          final String base64Audio = data['audio'];
          final Uint8List audioBytes = base64Decode(base64Audio);

          if (!_streamController.isClosed) {
            _streamController.add(audioBytes);
          }
        }
      });

      // 5. Handle Disconnection & Error
      _socket!.onDisconnect((_) {
        print(' SreRemoteDataSource: Disconnected from server');
        if (!_streamController.isClosed) {
          _streamController.addError("Connection closed by server.");
        }
      });

      _socket!.onError((error) {
        print(' SreRemoteDataSource Error: $error');
        if (!_streamController.isClosed) {
          _streamController.addError(error.toString());
        }
      });

      // 6. Open Connection manually
      _socket!.connect();

    } catch (e) {
      if (!_streamController.isClosed) {
        _streamController.addError(e);
      }
    }
  }

  @override
  void sendAudio(Uint8List audioChunk) {
    // Ensure socket is active before pumping audio data from microphone
    if (_socket != null && _socket!.connected) {
      // Socket.IO cannot send raw bytes efficiently in Flutter,
      // we must convert it to Base64 before sending to Python.
      final String base64String = base64Encode(audioChunk);
      _socket!.emit('send_audio', {'audio': base64String});
    }
  }

  @override
  void closeConnection() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}