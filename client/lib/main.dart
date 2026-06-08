import 'dart:convert' show jsonDecode;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:plainsight/app.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/config/firebase_config.dart';
import 'package:plainsight/core/utils/app_logger.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  try {
    bool useEmulator = const bool.fromEnvironment(
      'USE_EMULATOR',
      defaultValue: !kReleaseMode,
    );
    String environment = const String.fromEnvironment(
      'ENVIRONMENT',
      defaultValue: kReleaseMode ? 'dev' : 'local',
    );

    FirebaseOptions? dynamicOptions;

    if (kIsWeb) {
      final host = Uri.base.host;
      final isLocal =
          host == 'localhost' ||
          host == '127.0.0.1' ||
          host.startsWith('192.168.') ||
          host.startsWith('10.') ||
          host.startsWith('172.');
      if (!isLocal) {
        useEmulator = false;
        if (environment == 'local') {
          environment = 'dev';
        }

        try {
          final initUri = Uri.base.resolve('/__/firebase/init.json');
          final response = await http.get(initUri);
          if (response.statusCode == 200) {
            final config = jsonDecode(response.body) as Map<String, dynamic>;
            dynamicOptions = FirebaseOptions(
              apiKey: config['apiKey'] as String,
              appId: config['appId'] as String,
              messagingSenderId: config['messagingSenderId'] as String,
              projectId: config['projectId'] as String,
              authDomain: config['authDomain'] as String?,
              storageBucket: config['storageBucket'] as String?,
              measurementId: config['measurementId'] as String?,
            );
            AppLogger.info(
              'Successfully fetched dynamic Firebase configuration from hosting',
            );
          } else {
            AppLogger.error(
              'Failed to load dynamic Firebase configuration: HTTP ${response.statusCode}',
            );
          }
        } catch (e, stack) {
          AppLogger.error(
            'Error fetching dynamic Firebase configuration from hosting',
            e,
            stack,
          );
        }
      } else {
        const hasExplicitEmulator = bool.hasEnvironment('USE_EMULATOR');
        if (!hasExplicitEmulator) {
          useEmulator = true;
          const hasExplicitEnv = bool.hasEnvironment('ENVIRONMENT');
          if (!hasExplicitEnv) {
            environment = 'local';
          }
        }
      }
    }

    AppStateNotifier.useEmulator = useEmulator;
    AppStateNotifier.environment = environment;

    final options =
        dynamicOptions ??
        ((environment == 'dev') ? devFirebaseOptions : localFirebaseOptions);
    await Firebase.initializeApp(options: options);

    try {
      if (kIsWeb) {
        const recaptchaKey = String.fromEnvironment('RECAPTCHA_SITE_KEY');
        if (recaptchaKey.isNotEmpty) {
          await FirebaseAppCheck.instance.activate(
            providerWeb: ReCaptchaV3Provider(recaptchaKey),
          );
        } else {
          AppLogger.warning(
            'Firebase App Check was not activated: RECAPTCHA_SITE_KEY is not configured.',
          );
        }
      } else {
        await FirebaseAppCheck.instance.activate(
          providerAndroid: kReleaseMode
              ? const AndroidPlayIntegrityProvider()
              : const AndroidDebugProvider(),
          providerApple: kReleaseMode
              ? const AppleAppAttestWithDeviceCheckFallbackProvider()
              : const AppleDebugProvider(),
        );
      }
      AppLogger.info('Firebase App Check activated successfully');
    } catch (e, stack) {
      AppLogger.error('Failed to activate Firebase App Check', e, stack);
    }

    if (useEmulator) {
      final String host = kIsWeb
          ? '127.0.0.1'
          : (Platform.isAndroid ? '10.0.2.2' : '127.0.0.1');

      // Retrieve ports dynamically from URL query parameters (for E2E/parallel runs)
      // or compile-time environment flags, falling back to defaults.
      int firestorePort = 8081;
      int authPort = 9099;
      int functionsPort = 5002;

      try {
        final baseUri = Uri.base;
        final queryParams = baseUri.queryParameters;
        AppLogger.info(
          '🔍 Booting client. Uri: $baseUri, QueryParams: $queryParams',
        );

        if (queryParams.containsKey('firestore_port')) {
          firestorePort = int.parse(queryParams['firestore_port']!);
        } else {
          firestorePort = const int.fromEnvironment(
            'FIRESTORE_PORT',
            defaultValue: 8081,
          );
        }

        if (queryParams.containsKey('auth_port')) {
          authPort = int.parse(queryParams['auth_port']!);
        } else {
          authPort = const int.fromEnvironment('AUTH_PORT', defaultValue: 9099);
        }

        if (queryParams.containsKey('functions_port')) {
          functionsPort = int.parse(queryParams['functions_port']!);
        } else {
          functionsPort = const int.fromEnvironment(
            'FUNCTIONS_PORT',
            defaultValue: 0,
          );
          if (functionsPort == 0) {
            final int offset = firestorePort - 8081;
            functionsPort = 5002 + offset;
          }
        }
      } catch (e) {
        AppLogger.error('⚠️ Error parsing query parameters for ports', e);
        firestorePort = const int.fromEnvironment(
          'FIRESTORE_PORT',
          defaultValue: 8081,
        );
        authPort = const int.fromEnvironment('AUTH_PORT', defaultValue: 9099);
        functionsPort = const int.fromEnvironment(
          'FUNCTIONS_PORT',
          defaultValue: 0,
        );
        if (functionsPort == 0) {
          final int offset = firestorePort - 8081;
          functionsPort = 5002 + offset;
        }
      }

      AppStateNotifier.functionsPort = functionsPort;

      AppLogger.info(
        '🔌 Connecting to emulators. Host: $host, Firestore: $firestorePort, Auth: $authPort, Functions: $functionsPort',
      );
      // Connect to local Firestore emulator
      FirebaseFirestore.instance.useFirestoreEmulator(host, firestorePort);
      // Enable Firestore offline persistence and unlimited caching
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      // Connect to local Auth emulator
      await FirebaseAuth.instance.useAuthEmulator(host, authPort);
    } else {
      AppLogger.info(
        '🚀 Running directly against dev cloud Firebase database: ${options.projectId}',
      );
      // Ensure Firestore settings are still applied without the emulator
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    }
  } catch (e, stack) {
    AppLogger.error('Firebase initialization failure', e, stack);
  }
  runApp(const MyApp());
}
