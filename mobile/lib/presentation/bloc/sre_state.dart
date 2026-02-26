part of 'sre_bloc.dart';

enum SreStatus { initial, connecting, connected, disconnected, error }

class SreState {
  final SreStatus status;
  final Uint8List? lastAudioChunk; // Audio to be played by the speaker
  final Map<String, dynamic>? dashboardData; // Reactive metrics for the UI
  final String? errorMessage;

  SreState({
    this.status = SreStatus.initial,
    this.lastAudioChunk,
    this.dashboardData,
    this.errorMessage,
  });

  SreState copyWith({
    SreStatus? status,
    Uint8List? lastAudioChunk,
    Map<String, dynamic>? dashboardData,
    String? errorMessage,
  }) {
    return SreState(
      status: status ?? this.status,
      lastAudioChunk: lastAudioChunk ?? this.lastAudioChunk,
      dashboardData: dashboardData ?? this.dashboardData,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}