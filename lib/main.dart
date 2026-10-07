import 'package:flutter/material.dart';

import 'screens/history_screen.dart';

void main() {
  runApp(const IncognitoApp());
}

class IncognitoApp extends StatelessWidget {
  const IncognitoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Incognito',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF49615D),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF49615D),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: const HistoryScreen(),
    );
  }
}

