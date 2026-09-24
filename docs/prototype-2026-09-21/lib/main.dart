import 'package:flutter/material.dart';

import 'data/pact_repository.dart';
import 'features/pacts/pact_controller.dart';
import 'features/pacts/pacta_home_page.dart';

void main() {
  runApp(const PactaApp());
}

class PactaApp extends StatefulWidget {
  const PactaApp({super.key});

  @override
  State<PactaApp> createState() => _PactaAppState();
}

class _PactaAppState extends State<PactaApp> {
  late final PactController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PactController(InMemoryPactRepository())..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pacta',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2559D6),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8FC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF7F8FC),
          foregroundColor: Color(0xFF172033),
          scrolledUnderElevation: 0,
        ),
      ),
      home: PactaHomePage(controller: _controller),
    );
  }
}
