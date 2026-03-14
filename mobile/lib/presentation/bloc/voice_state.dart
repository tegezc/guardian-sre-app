part of 'voice_bloc.dart';

sealed class VoiceState extends Equatable {
  const VoiceState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any interaction.
class VoiceIdle extends VoiceState {}

/// Active state when the microphone is listening and streaming.
class VoiceRecording extends VoiceState {}

/// State representing server analysis (e.g., parsing SRE metrics).
class VoiceProcessing extends VoiceState {
  final String statusMessage;
  final Map<String, dynamic>? metrics; // 🌟 NEW: Penampung data metrik JSON

  const VoiceProcessing(this.statusMessage, {this.metrics});

  @override
  List<Object?> get props => [statusMessage, metrics];
}

/// State representing a failure in connection or permissions.
class VoiceError extends VoiceState {
  final String errorMessage;
  const VoiceError(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}