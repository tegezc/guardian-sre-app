import 'dart:typed_data';
import 'package:injectable/injectable.dart';
import '../../domain/entities/sre_message.dart';
import '../../domain/repositories/sre_repository.dart';
import '../datasources/sre_remote_data_source.dart';
import '../models/sre_message_model.dart';

@Singleton(as: SreRepository)
class SreRepositoryImpl implements SreRepository {
  final SreRemoteDataSource remoteDataSource;

  SreRepositoryImpl(this.remoteDataSource);

  @override
  Stream<SreMessage> getSreStream() {
    return remoteDataSource.liveStream.map(
      (rawData) => SreMessageModel.fromRawData(rawData),
    );
  }

  @override
  Future<void> sendVoiceCommand(Uint8List audio) async {
    remoteDataSource.sendAudio(audio);
  }

  @override
  void stopSession() {
    remoteDataSource.closeConnection();
  }
}