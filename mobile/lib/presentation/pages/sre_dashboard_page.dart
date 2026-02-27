import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/sre_bloc.dart';
import '../widgets/voice_pulse_widget.dart';
import '../widgets/metric_card_widget.dart';

class SreDashboardPage extends StatelessWidget {
  const SreDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117), // Dark SRE Theme
      appBar: AppBar(
        title: const Text('THE GUARDIAN SRE', style: TextStyle(letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          BlocBuilder<SreBloc, SreState>(
            builder: (context, state) {
              return Icon(
                Icons.circle,
                color: state.status == SreStatus.connected ? Colors.green : Colors.red,
                size: 12,
              );
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          const Expanded(
            flex: 2,
            child: Center(
              // Component for Voice Visualization
              child: VoicePulseWidget(),
            ),
          ),
          Expanded(
            flex: 3,
            child: BlocBuilder<SreBloc, SreState>(
              builder: (context, state) {
                if (state.dashboardData == null) {
                  return const Center(
                    child: Text(
                      "Waiting for system metrics...",
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                
                // Reactive Dashboard: Automatically updates based on metadata
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      "LIVE MONITORING",
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.blueAccent),
                    ),
                    const SizedBox(height: 12),
                    MetricCardWidget(
                      title: state.dashboardData!['service'] ?? 'Unknown Service',
                      value: state.dashboardData!['value'] ?? 'N/A',
                      label: state.dashboardData!['metric'] ?? 'Metric',
                      isAlert: state.dashboardData!['status'] == 'degraded',
                    ),
                    // You can add more widgets like LogStreamer here
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.large(
        onPressed: () {
          // Toggle Session
          context.read<SreBloc>().add(StartSreSession());
        },
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.mic, color: Colors.white),
      ),
    );
  }
}