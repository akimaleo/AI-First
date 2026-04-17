import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app.dart';
import 'shared/services/firestore_service.dart';
import 'shared/services/perf_instrumentation.dart';
import 'shared/services/sentry_service.dart';

Future<void> main() async {
  // Stamp the start of process boot before any heavy work — paired with
  // PerfInstrumentation.completeStartupAndRecord() in HomeScreen for the
  // GUSAA-43 startup baseline.
  PerfInstrumentation.markAppStart();
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase is the sole backend after the GUSAA-50 Supabase removal. Native
  // config comes from android/app/google-services.json (gitignored; written by
  // CI from the GOOGLE_SERVICES_JSON_BASE64 secret). If the file is absent on
  // a dev machine the try/catch keeps the app bootable for UI-only work.
  var firebaseReady = false;
  try {
    await Firebase.initializeApp();
    firebaseReady = true;
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('Firebase.initializeApp() skipped: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // Anonymous auth — every client gets a stable uid. Board owner chose
  // anonymous-only auth for the MVP.
  if (firebaseReady && FirebaseAuth.instance.currentUser == null) {
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('FirebaseAuth.signInAnonymously() failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  // Seed the challenges collection on first run so the game is playable
  // immediately without manual Firestore console work.
  if (firebaseReady) {
    try {
      final service = FirestoreService(
        FirebaseFirestore.instance,
        FirebaseAuth.instance,
      );
      await service.seedChallengesIfEmpty();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Challenge seeding failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  await initSentry(() async {
    if (sentryDsn.isNotEmpty) {
      // Route uncaught Flutter framework errors into Sentry. Keep the default
      // console presentation in debug so engineers still see stack traces.
      final previous = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) async {
        await Sentry.captureException(
          details.exception,
          stackTrace: details.stack,
        );
        if (kDebugMode) {
          previous?.call(details);
        }
      };
    }

    runApp(
      const ProviderScope(
        child: SyncOrSinkApp(),
      ),
    );
  });
}
