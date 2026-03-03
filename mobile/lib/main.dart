import 'package:flutter/material.dart';
// import file injection setup Anda (misal: get_it setup)
import 'core/di/injection.dart';
import 'presentation/pages/voice_dashboard_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Dependency Injection (SreRemoteDataSource, VoiceRepository, VoiceBloc)
  configureDependencies();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guardian SRE',
      theme: ThemeData.dark(),
      home: const VoiceDashboardPage(),
    );
  }
}