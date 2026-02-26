import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import '../../../domain/entities/sre_message.dart';
import '../../../domain/usecases/get_sre_stream_use_case.dart';
import '../../../domain/repositories/sre_repository.dart';

part 'sre_event.dart';
part 'sre_state.dart';

@injectable
class SreBloc extends Bloc<SreEvent, SreState> {
  final GetSreStreamUseCase _getSreStreamUseCase;
  final SreRepository _repository;
  StreamSubscription? _sreSubscription;

  SreBloc(this._getSreStreamUseCase, this._repository) : super(SreState()) {
    on<StartSreSession>(_onStartSession);
    on<SendAudioChunk>(_onSendAudio);
    on<ReceivedSreMessage>(_onReceivedMessage);
    on<StopSreSession>(_onStopSession);
  }

  Future<void> _onStartSession(StartSreSession event, Emitter<SreState> emit) async {
    emit(state.copyWith(status: SreStatus.connecting));
    
    try {
      // Cancel previous subscription if exists
      await _sreSubscription?.cancel();
      
      // Listen to the live stream from Domain layer
      _sreSubscription = _getSreStreamUseCase.execute().listen(
        (message) => add(ReceivedSreMessage(message)),
        onError: (e) => emit(state.copyWith(status: SreStatus.error, errorMessage: e.toString())),
      );

      emit(state.copyWith(status: SreStatus.connected));
    } catch (e) {
      emit(state.copyWith(status: SreStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onSendAudio(SendAudioChunk event, Emitter<SreState> emit) async {
    // Forward the audio chunk to the repository
    await _repository.sendVoiceCommand(event.audio);
  }

  void _onReceivedMessage(ReceivedSreMessage event, Emitter<SreState> emit) {
    // Update state based on what we received: Audio or Metadata
    emit(state.copyWith(
      lastAudioChunk: event.message.audioChunk,
      dashboardData: event.message.metadata,
    ));
  }

  Future<void> _onStopSession(StopSreSession event, Emitter<SreState> emit) async {
    await _sreSubscription?.cancel();
    _repository.stopSession();
    emit(state.copyWith(status: SreStatus.disconnected));
  }

  @override
  Future<void> close() {
    _sreSubscription?.cancel();
    return super.close();
  }
}