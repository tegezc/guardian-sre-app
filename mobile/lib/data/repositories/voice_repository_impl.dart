import 'dart:typed_data';
import 'package:injectable/injectable.dart';
import '../../domain/repositories/voice_repository.dart';
import '../datasources/sre_remote_data_source.dart';

@Injectable(as: VoiceRepository)
class VoiceRepositoryImpl implements VoiceRepository {
  final SreRemoteDataSource _remoteDataSource;

  VoiceRepositoryImpl(this._remoteDataSource);

  @override
  Stream<dynamic> get voiceStream => _remoteDataSource.liveStream;

  @override
  void connect() {
    _remoteDataSource.connect(); // URL is handled internally by DI
  }

  @override
  void sendAudio(Uint8List audioChunk) {
    _remoteDataSource.sendAudio(audioChunk);
  }

  @override
  void disconnect() {
    _remoteDataSource.closeConnection();
  }
}