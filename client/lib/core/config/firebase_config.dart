import 'package:firebase_core/firebase_core.dart';

/// Local emulator Firebase configuration options.
const FirebaseOptions localFirebaseOptions = FirebaseOptions(
  apiKey: String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'AIzaSyMockApiKeyForLocalEmulator_32ch',
  ),
  authDomain: 'demo-plainsightil.firebaseapp.com',
  appId: 'demo-app-id',
  messagingSenderId: 'demo-sender-id',
  projectId: 'demo-plainsightil',
);
