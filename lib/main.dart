import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app.dart';
import 'shared/services/perf_instrumentation.dart';
import 'shared/services/sentry_service.dart';

Future<void> main() async {
  // Stamp the start of process boot before any heavy work — paired with
  // PerfInstrumentation.completeStartupAndRecord() in HomeScreen for the
  // GUSAA-43 startup baseline.
  PerfInstrumentation.markAppStart();
  WidgetsFlutterBinding.ensureInitialized();

  // Call runApp() immediately so the user sees UI right away instead of a
  // black screen. All heavy async init (Firebase, auth, seeding) now runs
  // inside the widget tree via the initializationProvider in app.dart.
  await initSentry(() async {
    if (sentryDsn.isNotEmpty) {
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
