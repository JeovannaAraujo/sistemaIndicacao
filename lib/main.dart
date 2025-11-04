import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Telas do seu app
import 'Login/login.dart';
import 'Cliente/home_cliente.dart';
import 'Administrador/perfil_admin.dart';
import 'Prestador/home_prestador.dart';
import 'firebase_options.dart'; // importa o arquivo novo

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase inicializando com opções corretas
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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

      // Delegates e locales
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR'), Locale('en', 'US')],
      locale: const Locale('pt', 'BR'),

      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepPurple),

      // Escolhe a tela inicial conforme estado do FirebaseAuth
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // Usuário logado
          if (snapshot.hasData) {
            final uid = snapshot.data!.uid;

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('usuarios')
                  .doc(uid)
                  .get(),
              builder: (context, userSnap) {
                if (userSnap.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                if (!userSnap.hasData || !userSnap.data!.exists) {
                  return const LoginScreen();
                }

                final data = userSnap.data!.data() as Map<String, dynamic>;
                final tipoPerfil = (data['tipoPerfil'] ?? 'Cliente').toString().toLowerCase();

                // 🔥 CORREÇÃO: Verificação completa de todos os tipos
                switch (tipoPerfil) {
                  case 'administrador':
                    return const PerfilAdminScreen();
                  case 'prestador':
                    return const HomePrestadorScreen();
                  case 'ambos':
                    return const HomePrestadorScreen(); // ou PerfilAdminScreen()
                  default: // cliente
                    return const HomeScreen();
                }
              },
            );
          }

          // Usuário não logado → vai pro login
          return const LoginScreen();
        },
      ),
    );
  }
}