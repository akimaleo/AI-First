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
