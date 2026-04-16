import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

const String sentryDsn = String.fromEnvironment('SENTRY_DSN');

const String _sentryEnvOverride = String.fromEnvironment('SENTRY_ENVIRONMENT');

/// Returns the Sentry environment for the current build.
///
/// Resolution order: explicit `--dart-define=SENTRY_ENVIRONMENT`,
/// then `dev` in debug builds, otherwise `prod`.
String resolveSentryEnvironment({bool? isDebugBuild}) {
  if (_sentryEnvOverride.isNotEmpty) return _sentryEnvOverride;
  return (isDebugBuild ?? kDebugMode) ? 'dev' : 'prod';
}

/// Initializes Sentry and runs [appRunner].
///
/// If [sentryDsn] is empty (e.g. local dev with no DSN provisioned), this is a
/// no-op: it simply invokes [appRunner] and Flutter framework errors fall back
/// to the platform default (`FlutterError.presentError`).
Future<void> initSentry(FutureOr<void> Function() appRunner) async {
  if (sentryDsn.isEmpty) {
    await appRunner();
    return;
  }

  await SentryFlutter.init(
    (options) {
      options
        ..dsn = sentryDsn
        ..environment = resolveSentryEnvironment()
        ..tracesSampleRate = 0.2
        ..attachScreenshot = false
        // ignore: experimental_member_use
        ..attachViewHierarchy = false
        ..sendDefaultPii = false
        ..beforeSend = _beforeSend
        ..beforeBreadcrumb = _beforeBreadcrumb;
    },
    appRunner: appRunner,
  );
}

/// Throws a synthetic exception so the team can verify the Sentry pipeline
/// end-to-end. Wired up to the debug-only smoke-test button in [HomeScreen].
void triggerSentrySmokeTest() {
  throw StateError(
    'Sentry smoke test from Sync or Sink (GUSAA-42) — safe to ignore.',
  );
}

// --------------------------------------------------------------------------
// PII scrubbing
// --------------------------------------------------------------------------

// Email addresses.
final RegExp _emailPattern = RegExp(
  r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}',
);

// Compact JWT-shaped tokens (header.payload.signature). Supabase access tokens
// and Sentry-side auth headers all match this shape.
final RegExp _jwtPattern = RegExp(
  r'eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+',
);

// data:image/<type>;base64,<payload> — selfie photos can travel inline through
// the AI pipeline. Strip the payload, not the marker, so debugging is still
// possible.
final RegExp _dataUriPattern = RegExp(
  r'data:image/[A-Za-z0-9.+\-]+;base64,[A-Za-z0-9+/=]+',
);

// Bearer authorization headers.
final RegExp _bearerPattern = RegExp(
  r'bearer\s+[A-Za-z0-9._\-]+',
  caseSensitive: false,
);

const String _redacted = '[redacted]';

/// Public for tests. Replaces emails, JWTs, bearer tokens, and inline base64
/// image payloads with `[redacted]`.
String scrubSensitiveText(String input) {
  if (input.isEmpty) return input;
  return input
      .replaceAll(_dataUriPattern, 'data:image/<redacted>;base64,$_redacted')
      .replaceAll(_jwtPattern, _redacted)
      .replaceAll(_bearerPattern, 'Bearer $_redacted')
      .replaceAll(_emailPattern, _redacted);
}

/// Public for tests. Recursively scrubs string leaves of [value].
Object? scrubSensitiveValue(Object? value) {
  if (value == null) return null;
  if (value is String) return scrubSensitiveText(value);
  if (value is Map) {
    final out = <String, dynamic>{};
    value.forEach((key, v) {
      final keyStr = key.toString();
      if (_isSensitiveKey(keyStr)) {
        out[keyStr] = _redacted;
      } else {
        out[keyStr] = scrubSensitiveValue(v);
      }
    });
    return out;
  }
  if (value is Iterable) {
    return value.map(scrubSensitiveValue).toList();
  }
  return value;
}

bool _isSensitiveKey(String key) {
  final k = key.toLowerCase();
  return k == 'email' ||
      k == 'access_token' ||
      k == 'refresh_token' ||
      k == 'authorization' ||
      k == 'apikey' ||
      k == 'api_key' ||
      k == 'modifiedimagepath' ||
      k == 'modified_image_path' ||
      k == 'originalimagepath' ||
      k == 'original_image_path' ||
      k == 'image';
}

Map<String, String>? _scrubTags(Map<String, String>? tags) {
  if (tags == null) return null;
  final out = <String, String>{};
  tags.forEach((k, v) {
    out[k] = _isSensitiveKey(k) ? _redacted : scrubSensitiveText(v);
  });
  return out;
}

FutureOr<SentryEvent?> _beforeSend(SentryEvent event, Hint hint) {
  final scrubbedExtra =
      // ignore: deprecated_member_use
      scrubSensitiveValue(event.extra) as Map<String, dynamic>?;
  final scrubbedTags = _scrubTags(event.tags);

  final scrubbedExceptions = event.exceptions
      ?.map((e) => e.copyWith(
            value: e.value == null ? null : scrubSensitiveText(e.value!),
          ))
      .toList();

  final scrubbedMessage = event.message == null
      ? null
      : SentryMessage(
          scrubSensitiveText(event.message!.formatted),
          template: event.message!.template,
          params: event.message!.params,
        );

  // Drop the entire user object; we never want to ship identifying user fields
  // (email, ip, username) to Sentry. id remains useful and safe — keep it only
  // if explicitly set.
  final scrubbedUser = event.user == null
      ? null
      : SentryUser(id: event.user!.id);

  return event.copyWith(
    user: scrubbedUser,
    message: scrubbedMessage,
    exceptions: scrubbedExceptions,
    // ignore: deprecated_member_use
    extra: scrubbedExtra,
    tags: scrubbedTags,
  );
}

Breadcrumb? _beforeBreadcrumb(Breadcrumb? crumb, Hint hint) {
  if (crumb == null) return null;

  final data = crumb.data;
  final scrubbedData = data == null
      ? null
      : (scrubSensitiveValue(Map<String, dynamic>.from(data))
          as Map<String, dynamic>);

  return crumb.copyWith(
    message: crumb.message == null ? null : scrubSensitiveText(crumb.message!),
    data: scrubbedData,
  );
}
