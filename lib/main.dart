import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'Login/login.dart'; // sua tela inicial

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase
  await Firebase.initializeApp();

  // Locale pt_BR para DateFormat, DatePicker etc.
  Intl.defaultLocale = 'pt_BR';
  await initializeDateFormatting('pt_BR');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistema de Indicação',
      debugShowCheckedModeBanner: false,

      // IMPORTANTE: delegates e locales
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
        Locale('en', 'US'), // pode manter outros se quiser
      ],
      locale: const Locale('pt', 'BR'),

      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepPurple),

      home: const LoginScreen(), // ou sua home
    );
  }
}
