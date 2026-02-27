import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/di/injection.dart';
import 'presentation/bloc/sre_bloc.dart';
import 'presentation/pages/sre_dashboard_page.dart';

void main() async {
  // 1. Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize Dependency Injection (GetIt + Injectable)
  configureDependencies();

  runApp(const TheGuardianApp());
}

class TheGuardianApp extends StatelessWidget {
  const TheGuardianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      // 3. Inject SreBloc at the top level using GetIt
      providers: [
        BlocProvider<SreBloc>(
          create: (context) => getIt<SreBloc>(),
        ),
      ],
      child: MaterialApp(
        title: 'The Guardian SRE',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.blue,
          useMaterial3: true,
          fontFamily: 'RobotoMono', // Memberikan kesan technical/SRE
        ),
        home: const SreDashboardPage(),
      ),
    );
  }
}