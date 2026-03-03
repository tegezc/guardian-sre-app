import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../bloc/voice_bloc.dart';

/// The main entry point for the SRE Voice Assistant dashboard.
/// It wraps the view with the required BLoC provider injected via GetIt.
class VoiceDashboardPage extends StatelessWidget {
  const VoiceDashboardPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Inject the VoiceBloc into the widget tree
    return BlocProvider(
      create: (_) => GetIt.I<VoiceBloc>(),
      child: const VoiceDashboardView(),
    );
  }
}

/// The reactive view that listens to state changes and builds the UI accordingly.
class VoiceDashboardView extends StatelessWidget {
  const VoiceDashboardView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900], // Dark theme representing an SRE dashboard
      appBar: AppBar(
        title: const Text('The Guardian SRE'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Center(
        child: BlocConsumer<VoiceBloc, VoiceState>(
          listener: (context, state) {
            // Gracefully handle error states by showing a SnackBar
            if (state is VoiceError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage),
                  backgroundColor: Colors.redAccent,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          builder: (context, state) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildVisualizer(state),
                const SizedBox(height: 60),
                _buildStatusText(state),
                const SizedBox(height: 40),
                _buildMicButton(context, state),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Builds the status text reflecting the current operational state of the BLoC.
  Widget _buildStatusText(VoiceState state) {
    String text = "Tap to call Guardian";
    Color color = Colors.grey;

    if (state is VoiceRecording) {
      text = "Listening to SRE commands...";
      color = Colors.greenAccent;
    } else if (state is VoiceProcessing) {
      // Safely access the statusMessage from the VoiceProcessing state
      text = state.statusMessage;
      color = Colors.orangeAccent;
    } else if (state is VoiceError) {
      text = "Connection lost or error occurred.";
      color = Colors.redAccent;
    }

    return Text(
      text,
      style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w500),
      textAlign: TextAlign.center,
    );
  }

  /// Builds the interactive microphone button that dispatches toggle events.
  Widget _buildMicButton(BuildContext context, VoiceState state) {
    final isRecording = state is VoiceRecording;
    final isProcessing = state is VoiceProcessing;

    return GestureDetector(
      onTap: () {
        // Dispatch the toggle event to the BLoC to handle start/stop logic
        context.read<VoiceBloc>().add(ToggleVoiceRecording());
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isRecording ? Colors.green.withOpacity(0.2) : Colors.blueGrey[800],
          border: Border.all(
            color: isRecording ? Colors.greenAccent : Colors.blueGrey,
            width: isRecording ? 3 : 1,
          ),
          boxShadow: isRecording
              ? [
            BoxShadow(
              color: Colors.greenAccent.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 5,
            )
          ]
              : [],
        ),
        child: Icon(
          isRecording ? Icons.stop_rounded : Icons.mic_rounded,
          size: 64,
          color: isRecording
              ? Colors.greenAccent
              : (isProcessing ? Colors.grey : Colors.white),
        ),
      ),
    );
  }

  /// Placeholder widget for the sound wave pulse visualizer.
  Widget _buildVisualizer(VoiceState state) {
    if (state is VoiceRecording) {
      return const Icon(Icons.graphic_eq, size: 80, color: Colors.greenAccent);
    }
    return const Icon(Icons.monitor_heart, size: 80, color: Colors.blueGrey);
  }
}