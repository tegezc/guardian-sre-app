import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';

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
  final AudioPlayer _audioPlayer = AudioPlayer();

  StreamSubscription<Uint8List>? _micSubscription;
  StreamSubscription<dynamic>? _serverSubscription;

  final List<int> _pcmBuffer = [];
  Timer? _playbackTimer;

  VoiceBloc(
      this._connectVoiceStream,
      this._sendAudioChunk,
      this._disconnectVoiceStream,
      ) : super(VoiceIdle()) {

    // Konfigurasi Audio OS untuk Full-Duplex (VoIP Mode)
    _configureAudioSession();

    on<ToggleVoiceRecording>(_onToggleVoiceRecording);
    on<_AudioChunkCaptured>(_onAudioChunkCaptured);
    on<_ServerResponseReceived>(_onServerResponseReceived);
    on<_GeminiReadySignalReceived>(_onGeminiReadySignalReceived);

    on<_VoiceErrorOccurred>((event, emit) {
      emit(VoiceError(event.errorMessage));
      _stopAndCleanup();
    });

  }

  // Mencegah OS membunuh mikrofon saat speaker menyala
  Future<void> _configureAudioSession() async {
    await _audioPlayer.setAudioContext(AudioContext(
      android: AudioContextAndroid(
        isSpeakerphoneOn: true,
        stayAwake: true,
        contentType: AndroidContentType.speech,
        usageType: AndroidUsageType.voiceCommunication, // Mode Telepon/VoIP
        audioFocus: AndroidAudioFocus.none, // DILARANG MERAMPAS FOKUS DARI MIC!
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playAndRecord, // Wajib Play & Record
        options: [
          AVAudioSessionOptions.defaultToSpeaker,
          AVAudioSessionOptions.mixWithOthers, // Izinkan suara mic & speaker bercampur
          AVAudioSessionOptions.allowBluetooth,
          AVAudioSessionOptions.allowBluetoothA2DP,
        ],
      ),
    ));
    print("⚙️ Audio Session OS berhasil dikonfigurasi untuk Full-Duplex!");
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

      // Beri tahu UI bahwa kita sedang menunggu koneksi
      emit(const VoiceProcessing("Connecting to Guardian SRE..."));

      final serverStream = _connectVoiceStream.execute();

      _serverSubscription = serverStream.listen(
            (response) => add(_ServerResponseReceived(response)),
        onError: (error) => add(_VoiceErrorOccurred("Stream error: $error")),
        onDone: () => add(const _VoiceErrorOccurred("Server connection closed gracefully.")),
      );

      // MIKROFON TIDAK DINYALAKAN DI SINI LAGI.
      // Kita menunggu trigger dari _ServerResponseReceived.

    } catch (e) {
      emit(VoiceError("Failed to connect: ${e.toString()}"));
      await _stopAndCleanup();
    }
  }

  // NEW: Fungsi terpisah khusus untuk menyalakan mikrofon
  Future<void> _onGeminiReadySignalReceived(_GeminiReadySignalReceived event, Emitter<VoiceState> emit) async {
    try {

      // 3. Pastikan tidak ada rekaman ganda yang berjalan
      if (await _audioRecorder.isRecording()) {
        return;
      }

      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
        autoGain: true,
      );

      final micStream = await _audioRecorder.startStream(config);

      _micSubscription = micStream.listen((data) {
        add(_AudioChunkCaptured(data));
      });

      // Ubah UI menjadi mode merekam
      emit(VoiceRecording());
      print("🎤 Mikrofon Full-Duplex menyala. Siap menerima interupsi kapan saja...");
    } catch (e) {
      emit(VoiceError("Failed to start microphone: $e"));
      await _stopAndCleanup();
    }
  }

  void _onAudioChunkCaptured(_AudioChunkCaptured event, Emitter<VoiceState> emit) {
    _sendAudioChunk.execute(event.audioChunk);
  }

  void _onServerResponseReceived(_ServerResponseReceived event, Emitter<VoiceState> emit) {
    if (event.response is String) {
      final String message = event.response as String;
      emit(VoiceProcessing(message));

      // THE MAGIC TRIGGER: Jika backend mengirim "Online!", nyalakan mikrofon
      if (message.contains("Online!")) {
        add(_GeminiReadySignalReceived());
      }

    } else if (event.response is List<int>) {
      _pcmBuffer.addAll(event.response as List<int>);
      emit(const VoiceProcessing("Guardian is speaking..."));

      _playbackTimer?.cancel();
      _playbackTimer = Timer(const Duration(milliseconds: 300), () {
        _playAccumulatedAudio();
      });
    }
  }

  Future<void> _playAccumulatedAudio() async {
    if (_pcmBuffer.isEmpty) return;

    try {
      // 1. MATIKAN MIC SEMENTARA: Mencegah OS membunuh mic secara diam-diam
      // await _micSubscription?.cancel();
      // if (await _audioRecorder.isRecording()) {
      //   await _audioRecorder.stop();
      // }

      final Uint8List wavBytes = _addWavHeader(Uint8List.fromList(_pcmBuffer));
      _pcmBuffer.clear();

      // Jika AI tiba-tiba mengirim audio baru (karena interupsi), hentikan audio lama
      if (_audioPlayer.state == PlayerState.playing) {
        await _audioPlayer.stop();
      }

      // 2. Mainkan suara The Guardian
      print(" Memutar suara Guardian (Interupsi diizinkan)...");
      await _audioPlayer.play(BytesSource(wavBytes));
    } catch (e) {
      print("Audio playback error: $e");
    }
  }

  Uint8List _addWavHeader(Uint8List pcmBytes) {
    const int channels = 1;
    const int sampleRate = 16000;
    const int bitsPerSample = 16;
    const int byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    const int blockAlign = channels * (bitsPerSample ~/ 8);
    final int dataSize = pcmBytes.length;
    final int fileSize = 36 + dataSize;

    final ByteData header = ByteData(44);

    header.setUint8(0, 82); header.setUint8(1, 73); header.setUint8(2, 70); header.setUint8(3, 70);
    header.setUint32(4, fileSize, Endian.little);
    header.setUint8(8, 87); header.setUint8(9, 65); header.setUint8(10, 86); header.setUint8(11, 69);
    header.setUint8(12, 102); header.setUint8(13, 109); header.setUint8(14, 116); header.setUint8(15, 32);
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
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