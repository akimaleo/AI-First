import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'shared/services/perf_instrumentation.dart';
import 'shared/services/sentry_service.dart';

const _supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'http://localhost:54321',
);
const _supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: '',
);

Future<void> main() async {
  // Stamp the start of process boot before any heavy work — paired with
  // PerfInstrumentation.completeStartupAndRecord() in HomeScreen for the
  // GUSAA-43 startup baseline.
  PerfInstrumentation.markAppStart();
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: _supabaseUrl,
    anonKey: _supabaseAnonKey,
  );

  // Phase 1 of the Supabase -> Firebase migration (GUSAA-50): wire Firebase
  // alongside Supabase with no behaviour change. Native config comes from
  // android/app/google-services.json (gitignored; written by CI from the
  // GOOGLE_SERVICES_JSON_BASE64 secret). If the file is absent — common during
  // local dev — swallow the init failure so the app still boots on Supabase.
  try {
    await Firebase.initializeApp();
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('Firebase.initializeApp() skipped: $error');
      debugPrintStack(stackTrace: stackTrace);
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
