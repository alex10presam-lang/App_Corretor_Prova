// lib/main.dart
import 'dart:async'; // <-- Import necessário para o Zone
import 'package:flutter/foundation.dart'; // <-- Import necessário para kReleaseMode
import 'package:corretor_provas/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart'; // <-- Import do Crashlytics
import 'package:provider/provider.dart';
import 'firebase_options.dart';

// Imports de páginas
import 'login_page.dart'; // Corrigido para apontar para a pasta pages
import 'home_screen.dart';

// Import do tema
import 'theme.dart';

void main() async {
  // <<-- LÓGICA DE CAPTURA DE ERROS -->>
  // Garante que o Crashlytics seja inicializado antes de tudo
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Só envia relatórios para o Crashlytics em modo de produção (release)
      if (kReleaseMode) {
        // Captura erros do framework Flutter
        FlutterError.onError = (errorDetails) {
          FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
        };
        // Captura erros que acontecem fora do framework (ex: código assíncrono)
        PlatformDispatcher.instance.onError = (error, stack) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
          return true;
        };
      }

      runApp(
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
          child: const MyApp(),
        ),
      );
    },
    (error, stack) {
      // Tratamento final para erros que possam escapar
      if (kReleaseMode) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      }
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Correção de Provas',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          home: child,
        );
      },
      child: const AuthGate(),
    );
  }
}

// Widget auxiliar para manter a lógica de autenticação limpa
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const HomeScreen();
        }
        return const LoginPage();
      },
    );
  }
}
