import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/jump_provider.dart';
import 'screens/setup_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const JumpologyApp());
}

class JumpologyApp extends StatelessWidget {
  const JumpologyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => JumpProvider(),
      child: MaterialApp(
        title: 'Jumpology',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF00E5FF),
            surface: Color(0xFF0A0A0F),
          ),
          scaffoldBackgroundColor: const Color(0xFF0A0A0F),
        ),
        home: const SetupScreen(),
      ),
    );
  }
}
