import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 🔥 ចាប់ផ្ដើម Firebase ដោយប្រើ Options ដែលត្រឹមត្រូវ
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("✅ Firebase initialized successfully!");
  } catch (e) {
    debugPrint("⚠️ Firebase init error: $e");
  }

  // ☁️ ចាប់ផ្ដើម SyncService (Device Info)
  await SyncService().initialize();

  runApp(const MeterReadingApp());
}

class MeterReadingApp extends StatelessWidget {
  const MeterReadingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
