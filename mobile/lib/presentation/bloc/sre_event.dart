part of 'sre_bloc.dart';

abstract class SreEvent {}

/// Event to establish the connection with Gemini Live Agent.
class StartSreSession extends SreEvent {}

/// Event to send a chunk of audio from the microphone to the agent.
class SendAudioChunk extends SreEvent {
  final Uint8List audio;
  SendAudioChunk(this.audio);
}

/// Event to handle incoming data from the stream.
class ReceivedSreMessage extends SreEvent {
  final SreMessage message;
  ReceivedSreMessage(this.message);
}

/// Event to stop the session and close the socket.
class StopSreSession extends SreEvent {}