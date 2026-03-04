import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart'; // NEW IMPORT

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

  // NEW: Using the highly stable AudioPlayers package
  final AudioPlayer _audioPlayer = AudioPlayer();

  StreamSubscription<Uint8List>? _micSubscription;
  StreamSubscription<dynamic>? _serverSubscription;

  // NEW: Buffer to accumulate raw PCM bytes from Gemini
  final List<int> _pcmBuffer = [];

  // NEW: Timer to detect when Gemini finishes a sentence
  Timer? _playbackTimer;

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
    if (state is VoiceRecording || state is VoiceProcessing) {
      await _stopAndCleanup();
      emit(VoiceIdle());
      return;
    }

    try {
      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        status = await Permission.microphone.request();
        if (!status.isGranted) {
          emit(const VoiceError("Microphone permission denied by the system."));
          return;
        }
      }

      final serverStream = _connectVoiceStream.execute();

      _serverSubscription = serverStream.listen(
            (response) => add(_ServerResponseReceived(response)),
        onError: (error) => emit(VoiceError("Stream error: $error")),
      );

      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      );

      final micStream = await _audioRecorder.startStream(config);

      _micSubscription = micStream.listen((data) {
        add(_AudioChunkCaptured(data));
      });

      emit(VoiceRecording());
    } catch (e) {
      emit(VoiceError("Failed to start voice agent: ${e.toString()}"));
      await _stopAndCleanup();
    }
  }

  void _onAudioChunkCaptured(_AudioChunkCaptured event, Emitter<VoiceState> emit) {
    _sendAudioChunk.execute(event.audioChunk);
  }

  void _onServerResponseReceived(_ServerResponseReceived event, Emitter<VoiceState> emit) {
    if (event.response is String) {
      emit(VoiceProcessing(event.response));
    } else if (event.response is List<int>) {
      // 1. Accumulate incoming PCM bytes into the buffer
      _pcmBuffer.addAll(event.response as List<int>);

      emit(const VoiceProcessing("Guardian is speaking..."));

      // 2. Reset the timer. If 300ms pass without new bytes, play the audio!
      _playbackTimer?.cancel();
      _playbackTimer = Timer(const Duration(milliseconds: 300), () {
        _playAccumulatedAudio();
      });
    }
  }

  /// Wraps the accumulated PCM data with a WAV header and plays it safely.
  Future<void> _playAccumulatedAudio() async {
    if (_pcmBuffer.isEmpty) return;

    try {
      // Inject WAV header into the raw PCM data
      final Uint8List wavBytes = _addWavHeader(Uint8List.fromList(_pcmBuffer));

      // Clear the buffer for the next sentence
      _pcmBuffer.clear();

      // Play safely from memory (BytesSource)
      await _audioPlayer.play(BytesSource(wavBytes));
    } catch (e) {
      print("Audio playback error: $e");
    }
  }

  /// Generates a standard 44-byte WAV header for 16kHz, 16-bit Mono audio.
  Uint8List _addWavHeader(Uint8List pcmBytes) {
    const int channels = 1;
    const int sampleRate = 16000;
    const int bitsPerSample = 16;
    const int byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    const int blockAlign = channels * (bitsPerSample ~/ 8);
    final int dataSize = pcmBytes.length;
    final int fileSize = 36 + dataSize;

    final ByteData header = ByteData(44);

    // "RIFF" chunk descriptor
    header.setUint8(0, 82); header.setUint8(1, 73); header.setUint8(2, 70); header.setUint8(3, 70);
    header.setUint32(4, fileSize, Endian.little);
    // "WAVE" format
    header.setUint8(8, 87); header.setUint8(9, 65); header.setUint8(10, 86); header.setUint8(11, 69);
    // "fmt " sub-chunk
    header.setUint8(12, 102); header.setUint8(13, 109); header.setUint8(14, 116); header.setUint8(15, 32);
    header.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
    header.setUint16(20, 1, Endian.little);  // AudioFormat (1 = PCM)
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    // "data" sub-chunk
    header.setUint8(36, 100); header.setUint8(37, 97); header.setUint8(38, 116); header.setUint8(39, 97);
    header.setUint32(40, dataSize, Endian.little);

    final BytesBuilder builder = BytesBuilder();
    builder.add(header.buffer.asUint8List());
    builder.add(pcmBytes);

    return builder.toBytes();
  }

  Future<void> _stopAndCleanup() async {
    _playbackTimer?.cancel();
    await _micSubscription?.cancel();
    await _serverSubscription?.cancel();

    if (await _audioRecorder.isRecording()) {
      await _audioRecorder.stop();
    }

    await _audioPlayer.stop();
    _pcmBuffer.clear();

    _disconnectVoiceStream.execute();
  }

  @override
  Future<void> close() {
    _stopAndCleanup();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    return super.close();
  }
}