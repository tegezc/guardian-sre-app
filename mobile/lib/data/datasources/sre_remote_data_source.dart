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
  /// KRITIKAL: Pastikan baseUrl Anda di DI sekarang menggunakan "http://" bukan "ws://"
  SreRemoteDataSourceImpl(@Named("baseUrl") this.serverUrl);

  @override
  Stream<dynamic> get liveStream => _streamController.stream;

  @override
  void connect() {
    try {
      // 1. Inisialisasi Socket.IO dengan konfigurasi anti-putus
      _socket = IO.io(serverUrl, IO.OptionBuilder()
          .setTransports(['websocket']) // Paksa menggunakan jalur websocket agar real-time
          .disableAutoConnect()
          .build());

      // 2. Tangani Event Koneksi
      _socket!.onConnect((_) {
        print('✅ SreRemoteDataSource: Terhubung ke Socket.IO Server');
        // Wajib memicu backend untuk memulai sesi Gemini Live
        _socket!.emit('start_session');
      });

      // 3. Tangani Event Teks/Status (Opsional, jika backend mengirimkan log)
      _socket!.on('system_status', (data) {
        if (!_streamController.isClosed) {
          // Meneruskan pesan status sebagai string ke BLoC
          _streamController.add(data['message']);
        }
      });

      // 4. Tangani Event Audio dari Gemini
      _socket!.on('audio_response', (data) {
        if (data != null && data['audio'] != null) {
          // Clean Architecture: Sembunyikan kerumitan Base64 dari BLoC.
          // Kita decode di sini agar BLoC tetap menerima Uint8List seperti sebelumnya.
          final String base64Audio = data['audio'];
          final Uint8List audioBytes = base64Decode(base64Audio);

          if (!_streamController.isClosed) {
            _streamController.add(audioBytes);
          }
        }
      });

      // 5. Tangani Pemutusan & Error
      _socket!.onDisconnect((_) {
        print('❌ SreRemoteDataSource: Terputus dari server');
        if (!_streamController.isClosed) {
          _streamController.addError("Connection closed by server.");
        }
      });

      _socket!.onError((error) {
        print('⚠️ SreRemoteDataSource Error: $error');
        if (!_streamController.isClosed) {
          _streamController.addError(error.toString());
        }
      });

      // 6. Buka Koneksi secara manual
      _socket!.connect();

    } catch (e) {
      if (!_streamController.isClosed) {
        _streamController.addError(e);
      }
    }
  }

  @override
  void sendAudio(Uint8List audioChunk) {
    // Pastikan socket aktif sebelum memompa data suara dari mikrofon
    if (_socket != null && _socket!.connected) {
      // Socket.IO tidak bisa mengirim byte mentah dengan efisien di Flutter,
      // kita wajib mengubahnya menjadi Base64 sebelum dikirim ke Python.
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