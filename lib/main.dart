import 'package:provider/provider.dart';
import 'providers/user_provider.dart'; 
//provider is needed to be first imported to be used in the main.dart file

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:korhaz_app/screens/main_screen.dart';
import 'package:korhaz_app/constants/colors.dart';

import 'screens/login_screen.dart';

void main() async {
  // 1. Initialize the Flutter engine
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Initialize Firebase using the file we just generated!
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  //pause boot for 2 seconds to show the splash screen longer (it din't help)
  //await Future.delayed(const Duration(seconds: 2));

  runApp(
    // Wrap MyApp in a MultiProvider
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: const KorhazApp(),
    ),
  );
}

class KorhazApp extends StatelessWidget {
  const KorhazApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KorhazApp',
      // Let's use a Teal color theme since it's a hospital app!
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryTeal),
        useMaterial3: true, 
      ),
      // 3. Listen to the Auth State to decide which screen to show
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Show a loading circle while checking
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          // If the user is logged in, show a temporary success screen for now
          if (snapshot.hasData) {
            return const Scaffold(
              body: Center(
                child: MainScreen(),
              ),
            ); 
          }
          // If not logged in, show the Login Screen
          return const LoginScreen();
        },
      ),
    );
  }
}