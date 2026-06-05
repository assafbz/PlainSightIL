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

/// Dev cloud database Firebase configuration options.
const FirebaseOptions devFirebaseOptions = FirebaseOptions(
  apiKey: String.fromEnvironment('FIREBASE_DEV_API_KEY'),
  authDomain: 'plainsightil.firebaseapp.com',
  appId: '1:448274521578:web:82481de80f7bdfc892e693',
  messagingSenderId: '448274521578',
  projectId: 'plainsightil',
  storageBucket: 'plainsightil.firebasestorage.app',
  measurementId: 'G-Q2JGG6W5LF',
);
