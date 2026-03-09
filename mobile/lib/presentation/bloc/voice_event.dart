part of 'voice_bloc.dart';

sealed class VoiceEvent extends Equatable {
  const VoiceEvent();

  @override
  List<Object> get props => [];
}

/// Triggered by user interaction (e.g., tapping the microphone button).
class ToggleVoiceRecording extends VoiceEvent {}

/// Internal event fired when the microphone captures an audio frame.
class _AudioChunkCaptured extends VoiceEvent {
  final Uint8List audioChunk;
  const _AudioChunkCaptured(this.audioChunk);
}

/// Internal event fired when data is received from the WebSocket.
class _ServerResponseReceived extends VoiceEvent {
  final dynamic response;
  const _ServerResponseReceived(this.response);
}

// Internal event to safely handle stream errors without breaking BLoC rules
class _VoiceErrorOccurred extends VoiceEvent {
  final String errorMessage;

  const _VoiceErrorOccurred(this.errorMessage);

  @override
  List<Object> get props => [errorMessage];
}

class _GeminiReadySignalReceived extends VoiceEvent {}