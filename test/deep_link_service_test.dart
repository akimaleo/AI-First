import 'package:flutter_test/flutter_test.dart';
import 'package:sync_or_sink/shared/services/deep_link_service.dart';

void main() {
  group('DeepLinkService.mapUriToRoute', () {
    test('custom scheme syncorsink://join/<code> maps to /join/<CODE>', () {
      final route =
          DeepLinkService.mapUriToRoute(Uri.parse('syncorsink://join/abc123'));
      expect(route, '/join/ABC123');
    });

    test('universal https host maps to /join/<CODE>', () {
      final route = DeepLinkService.mapUriToRoute(
          Uri.parse('https://play.syncorsink.app/join/wx7y9z'));
      expect(route, '/join/WX7Y9Z');
    });

    test('returns null for unrelated schemes', () {
      expect(
        DeepLinkService.mapUriToRoute(Uri.parse('https://example.com/join/x')),
        isNull,
      );
    });

    test('returns null for unknown paths on the custom scheme', () {
      expect(
        DeepLinkService.mapUriToRoute(Uri.parse('syncorsink://profile/abc')),
        isNull,
      );
    });

    test('returns null when invite code is missing', () {
      expect(
        DeepLinkService.mapUriToRoute(Uri.parse('syncorsink://join/')),
        isNull,
      );
      expect(
        DeepLinkService.mapUriToRoute(
            Uri.parse('https://play.syncorsink.app/join/')),
        isNull,
      );
    });
  });
}
