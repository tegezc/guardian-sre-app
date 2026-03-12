import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../bloc/voice_bloc.dart';
import '../widgets/guardian_orb.dart';

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
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('The Guardian SRE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
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
                // Ruang kosong di atas agar seimbang
                const Spacer(flex: 2),

                // --- VISUALISASI AI (THE ORB) ---
                _buildVisualizer(state),

                const SizedBox(height: 60),

                // --- TEKS STATUS ---
                _buildStatusText(state),

                const Spacer(flex: 1),

                // --- TOMBOL MICROPHONE ---
                _buildMicButton(context, state),

                const SizedBox(height: 40),
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
      color = Colors.cyanAccent;
    } else if (state is VoiceProcessing) {
      // Safely access the message from the VoiceProcessing state
      text = state.statusMessage;
      color = Colors.purpleAccent;
    } else if (state is VoiceError) {
      text = "Connection lost or error occurred.";
      color = Colors.redAccent;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Text(
          text,
          key: ValueKey<String>(text),
          style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 1.2),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// Builds the interactive microphone button that dispatches toggle events.
  Widget _buildMicButton(BuildContext context, VoiceState state) {
    // Consider the session active during BOTH recording and processing
    final isActive = state is VoiceRecording || state is VoiceProcessing;

    return GestureDetector(
      onTap: () {
        context.read<VoiceBloc>().add(ToggleVoiceRecording());
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // Stay cyan/purple as long as the session is active
          color: isActive ? Colors.cyan.withOpacity(0.2) : Colors.blueGrey[800],
          border: Border.all(
            color: isActive ? Colors.cyanAccent : Colors.blueGrey,
            width: isActive ? 3 : 1,
          ),
          boxShadow: isActive
              ? [
            BoxShadow(
              color: Colors.cyanAccent.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 5,
            )
          ]
              : [],
        ),
        child: Icon(
          isActive ? Icons.stop_rounded : Icons.power_settings_new_rounded,
          size: 64,
          color: isActive ? Colors.cyanAccent : Colors.white,
        ),
      ),
    );
  }

  /// The magical sound wave pulse visualizer.
  Widget _buildVisualizer(VoiceState state) {
    String orbState = 'idle';

    if (state is VoiceRecording) {
      orbState = 'listening';
    } else if (state is VoiceProcessing) {
      orbState = 'speaking';
    } else if (state is VoiceError) {
      orbState = 'idle';
    }

    return GuardianOrb(state: orbState);
  }
}