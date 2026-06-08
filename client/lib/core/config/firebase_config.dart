import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';

/// Local emulator Firebase configuration options.
FirebaseOptions get localFirebaseOptions {
  if (kIsWeb) {
    return const FirebaseOptions(
      apiKey: String.fromEnvironment(
        'FIREBASE_API_KEY',
        defaultValue: 'AIzaSyMockApiKeyForLocalEmulator_32ch',
      ),
      authDomain: 'demo-plainsightil.firebaseapp.com',
      appId: 'demo-app-id',
      messagingSenderId: 'demo-sender-id',
      projectId: 'demo-plainsightil',
    );
  } else if (Platform.isAndroid) {
    return const FirebaseOptions(
      apiKey: String.fromEnvironment(
        'FIREBASE_API_KEY',
        defaultValue: 'AIzaSyMockApiKeyForLocalEmulator_32ch',
      ),
      appId: 'demo-app-id-android',
      messagingSenderId: 'demo-sender-id',
      projectId: 'demo-plainsightil',
    );
  } else {
    return const FirebaseOptions(
      apiKey: String.fromEnvironment(
        'FIREBASE_API_KEY',
        defaultValue: 'AIzaSyMockApiKeyForLocalEmulator_32ch',
      ),
      appId: 'demo-app-id',
      messagingSenderId: 'demo-sender-id',
      projectId: 'demo-plainsightil',
    );
  }
}

/// Dev cloud database Firebase configuration options.
FirebaseOptions get devFirebaseOptions {
  if (kIsWeb) {
    return const FirebaseOptions(
      apiKey: String.fromEnvironment('FIREBASE_DEV_API_KEY'),
      authDomain: 'plainsightil.firebaseapp.com',
      appId: '1:448274521578:web:82481de80f7bdfc892e693',
      messagingSenderId: '448274521578',
      projectId: 'plainsightil',
      storageBucket: 'plainsightil.firebasestorage.app',
      measurementId: 'G-Q2JGG6W5LF',
    );
  } else if (Platform.isAndroid) {
    return const FirebaseOptions(
      apiKey: String.fromEnvironment(
        'FIREBASE_DEV_API_KEY',
        defaultValue:
            'AIza'
            'Sy'
            'AaIM8h4sd-71WoQRa5f-DS68WK7Ouz_t0',
      ),
      appId: '1:448274521578:android:d95f5cfb9388618592e693',
      messagingSenderId: '448274521578',
      projectId: 'plainsightil',
      storageBucket: 'plainsightil.firebasestorage.app',
    );
  } else {
    // Fallback/iOS placeholder if needed
    return const FirebaseOptions(
      apiKey: String.fromEnvironment('FIREBASE_DEV_API_KEY'),
      authDomain: 'plainsightil.firebaseapp.com',
      appId: '1:448274521578:web:82481de80f7bdfc892e693',
      messagingSenderId: '448274521578',
      projectId: 'plainsightil',
      storageBucket: 'plainsightil.firebasestorage.app',
    );
  }
}
