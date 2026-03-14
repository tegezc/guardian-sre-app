import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../bloc/voice_bloc.dart';
import '../widgets/guardian_orb.dart';

class VoiceDashboardPage extends StatelessWidget {
  const VoiceDashboardPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GetIt.I<VoiceBloc>(),
      child: const VoiceDashboardView(),
    );
  }
}

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
                const Spacer(flex: 2),

                // --- THE ORB ---
                _buildVisualizer(state),

                const SizedBox(height: 30),

                // --- 🌟 NEW TERMINAL HUD ---
                _buildTerminalHUD(state),

                const SizedBox(height: 30),

                // --- STATUS TEXT ---
                _buildStatusText(state),

                const Spacer(flex: 1),

                // --- MICROPHONE BUTTON ---
                _buildMicButton(context, state),

                const SizedBox(height: 40),
              ],
            );
          },
        ),
      ),
    );
  }

  ///  SRE HUD Metrics Data Display
  Widget _buildTerminalHUD(VoiceState state) {
    // HUD ONLY APPEARS IF THERE IS METRICS DATA IN THE STATE
    if (state is VoiceProcessing && state.metrics != null) {
      final metrics = state.metrics!;
      final health = metrics['health'] as String? ?? 'UNKNOWN';
      final service = metrics['service'] as String? ?? 'Unknown Service';
      final errors = metrics['errors'] as String? ?? '-';
      final latency = metrics['action_latency'] as String?;

      // SRE status coloring logic
      Color healthColor = Colors.greenAccent;
      if (health.contains('CRITICAL') || health.contains('DEGRADED')) {
        healthColor = Colors.redAccent;
      } else if (health.contains('DORMANT') || health.contains('ZERO')) {
        healthColor = Colors.orangeAccent;
      }

      return AnimatedOpacity(
        opacity: 1.0,
        duration: const Duration(milliseconds: 500),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: healthColor.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: healthColor.withOpacity(0.05),
                blurRadius: 20,
                spreadRadius: 5,
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('[ REAL-TIME CLOUD METRICS ]',
                  style: TextStyle(color: healthColor, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 12),
              Text('TARGET : $service', style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 14)),
              Text('STATUS : $health', style: TextStyle(color: healthColor, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 14)),
              Text('ERRORS : $errors', style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 14)),

              // Display Latency ONLY if Cold Start action is executed
              if (latency != null) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Divider(color: Colors.white24, height: 1),
                ),
                Text('ACTION : COLD START PING', style: TextStyle(color: Colors.cyanAccent, fontFamily: 'monospace', fontSize: 14)),
                Text('LATENCY: $latency', style: TextStyle(color: Colors.cyanAccent, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 16)),
              ]
            ],
          ),
        ),
      );
    }

    // Return empty widget (invisible) if no metrics
    return const SizedBox(height: 0);
  }

  Widget _buildStatusText(VoiceState state) {
    String text = "Tap to call Guardian";
    Color color = Colors.grey;

    if (state is VoiceRecording) {
      text = "Listening to SRE commands...";
      color = Colors.cyanAccent;
    } else if (state is VoiceProcessing) {
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

  Widget _buildMicButton(BuildContext context, VoiceState state) {
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

  Widget _buildVisualizer(VoiceState state) {
    String orbState = 'idle';
    if (state is VoiceRecording) {
      orbState = 'listening';
    } else if (state is VoiceProcessing) orbState = 'speaking';

    return GuardianOrb(state: orbState);
  }
}