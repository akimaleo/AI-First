import 'package:flutter_test/flutter_test.dart';
import 'package:sync_or_sink/shared/services/sentry_service.dart';

void main() {
  group('scrubSensitiveText', () {
    test('redacts email addresses', () {
      final out = scrubSensitiveText(
        'Contact akimaelio@gmail.com or other.user+tag@example.co.uk',
      );
      expect(out, isNot(contains('akimaelio')));
      expect(out, isNot(contains('other.user')));
      expect(out, contains('[redacted]'));
    });

    test('redacts JWT-shaped tokens (Supabase access_token)', () {
      const jwt =
          'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1c2VyIn0.AbCdEf-1234_56789';
      final out = scrubSensitiveText('access_token=$jwt&foo=bar');
      expect(out, isNot(contains(jwt)));
      expect(out, contains('[redacted]'));
    });

    test('redacts inline base64 image data URIs', () {
      final out = scrubSensitiveText(
        'photo=data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEAYABg',
      );
      expect(out, isNot(contains('/9j/4AAQ')));
      expect(out, contains('data:image/<redacted>;base64,[redacted]'));
    });

    test('redacts Bearer authorization headers', () {
      final out = scrubSensitiveText('Bearer abc.def.ghi-token-12345');
      expect(out, isNot(contains('abc.def.ghi-token-12345')));
      expect(out, contains('Bearer [redacted]'));
    });

    test('returns empty input untouched', () {
      expect(scrubSensitiveText(''), '');
    });
  });

  group('scrubSensitiveValue', () {
    test('redacts sensitive map keys regardless of value type', () {
      final scrubbed = scrubSensitiveValue({
        'access_token': 'abc',
        'refresh_token': 'def',
        'authorization': 'Bearer xyz',
        'apikey': 'k',
        'modifiedImagePath': '/tmp/selfies/abc/output.jpg',
        'originalImagePath': '/tmp/selfies/abc/input.jpg',
        'image': 'data:image/jpeg;base64,xxxx',
        'safe_field': 'kept',
      }) as Map<String, dynamic>;

      expect(scrubbed['access_token'], '[redacted]');
      expect(scrubbed['refresh_token'], '[redacted]');
      expect(scrubbed['authorization'], '[redacted]');
      expect(scrubbed['apikey'], '[redacted]');
      expect(scrubbed['modifiedImagePath'], '[redacted]');
      expect(scrubbed['originalImagePath'], '[redacted]');
      expect(scrubbed['image'], '[redacted]');
      expect(scrubbed['safe_field'], 'kept');
    });

    test('recursively scrubs nested maps and lists', () {
      final scrubbed = scrubSensitiveValue({
        'breadcrumbs': [
          {
            'message': 'login as akimaelio@gmail.com',
            'data': {'access_token': 'abc'},
          },
        ],
      }) as Map<String, dynamic>;

      final crumbs = scrubbed['breadcrumbs'] as List;
      final first = crumbs.first as Map<String, dynamic>;
      expect(first['message'], isNot(contains('akimaelio')));
      expect(first['message'], contains('[redacted]'));
      expect((first['data'] as Map)['access_token'], '[redacted]');
    });

    test('passes null through', () {
      expect(scrubSensitiveValue(null), isNull);
    });

    test('preserves non-string scalars', () {
      expect(scrubSensitiveValue(42), 42);
      expect(scrubSensitiveValue(true), true);
    });
  });

  group('resolveSentryEnvironment', () {
    test('defaults to dev when no override and debug build', () {
      expect(resolveSentryEnvironment(isDebugBuild: true), 'dev');
    });

    test('defaults to prod when no override and release build', () {
      expect(resolveSentryEnvironment(isDebugBuild: false), 'prod');
    });
  });
}
