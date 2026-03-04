import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../domain/usecases/connect_voice_stream.dart';
import '../../domain/usecases/send_audio_chunk.dart';
import '../../domain/usecases/disconnect_voice_stream.dart';

part 'voice_event.dart';
part 'voice_state.dart';

@injectable
class VoiceBloc extends Bloc<VoiceEvent, VoiceState> {
  final ConnectVoiceStreamUseCase _connectVoiceStream;
  final SendAudioChunkUseCase _sendAudioChunk;
  final DisconnectVoiceStreamUseCase _disconnectVoiceStream;

  final AudioRecorder _audioRecorder = AudioRecorder();

  StreamSubscription<Uint8List>? _micSubscription;
  StreamSubscription<dynamic>? _serverSubscription;


  VoiceBloc(
      this._connectVoiceStream,
      this._sendAudioChunk,
      this._disconnectVoiceStream,
      ) : super(VoiceIdle()) {
    on<ToggleVoiceRecording>(_onToggleVoiceRecording);
    on<_AudioChunkCaptured>(_onAudioChunkCaptured);
    on<_ServerResponseReceived>(_onServerResponseReceived);
  }

  Future<void> _onToggleVoiceRecording(ToggleVoiceRecording event, Emitter<VoiceState> emit) async {
    // Gracefully stop if already recording
    if (state is VoiceRecording || state is VoiceProcessing) {
      await _stopAndCleanup();
      emit(VoiceIdle());
      return;
    }

    try {
      // 1. Enforce Runtime Permissions (Crucial for physical Android devices)
      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        status = await Permission.microphone.request();
        if (!status.isGranted) {
          emit(const VoiceError("Microphone permission denied by the system."));
          return;
        }
      }

      // 2. Establish WebSocket connection via UseCase and listen to server responses
      final serverStream = _connectVoiceStream.execute();

      _serverSubscription = serverStream.listen(
            (response) => add(_ServerResponseReceived(response)),
        onError: (error) => emit(VoiceError("Stream error: $error")),
      );

      // 3. Configure audio parameters strictly matching Gemini Live API requirements
      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits, // Requires Linear PCM 16-bit
        sampleRate: 16000,               // Requires 16kHz
        numChannels: 1,                  // Requires Mono
      );

      // 4. Start recording hardware stream
      final micStream = await _audioRecorder.startStream(config);

      print("DEBUG: Microphone stream started successfully.");

      // 5. Pipe microphone bytes to the internal BLoC event
      _micSubscription = micStream.listen(
            (data) {
          // Log to check if bytes are actually flowing
          print("DEBUG: Captured audio chunk: ${data.length} bytes");
          add(_AudioChunkCaptured(data));
        },
        onError: (error) {
          // Catch any hardware or platform-channel errors
          print("DEBUG ERROR: Microphone stream error: $error");
          emit(VoiceError("Mic error: $error"));
        },
        onDone: () {
          print("DEBUG WARNING: Microphone stream closed unexpectedly.");
        },
      );

      emit(VoiceRecording());
    } catch (e) {
      print("DEBUG FATAL: $e");
      emit(VoiceError("Failed to start voice agent: ${e.toString()}"));
      await _stopAndCleanup();
    }
  }

  void _onAudioChunkCaptured(_AudioChunkCaptured event, Emitter<VoiceState> emit) {
    // Delegate raw byte transmission to the UseCase
    _sendAudioChunk.execute(event.audioChunk);
  }

  void _onServerResponseReceived(_ServerResponseReceived event, Emitter<VoiceState> emit) {
    // Handle incoming data/metrics from the Python SRE backend
    print("Guardian Backend Response: ${event.response}");
    if (event.response is String) {
      // It's text from Gemini! Let's display it on the UI.
      emit(VoiceProcessing(event.response));
    } else {
      // It's binary audio data.
      // Keep the current status message but indicate audio is flowing.
      emit(const VoiceProcessing("Guardian is speaking..."));
    }
  }

  Future<void> _stopAndCleanup() async {
    await _micSubscription?.cancel();
    await _serverSubscription?.cancel();

    if (await _audioRecorder.isRecording()) {
      await _audioRecorder.stop();
    }

    _disconnectVoiceStream.execute();
  }

  @override
  Future<void> close() {
    _stopAndCleanup();
    _audioRecorder.dispose();
    return super.close();
  }
}

