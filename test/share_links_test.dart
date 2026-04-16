import 'package:flutter_test/flutter_test.dart';
import 'package:sync_or_sink/shared/services/share_links.dart';

void main() {
  group('ShareLinks.inviteLink', () {
    test('produces a universal https link with uppercased code', () {
      expect(
        ShareLinks.inviteLink('abc123'),
        'https://play.syncorsink.app/join/ABC123',
      );
    });

    test('trims surrounding whitespace', () {
      expect(
        ShareLinks.inviteLink('  hello  '),
        'https://play.syncorsink.app/join/HELLO',
      );
    });
  });

  group('ShareLinks.inviteDeepLink', () {
    test('uses the custom scheme', () {
      expect(
        ShareLinks.inviteDeepLink('wx7y9z'),
        'syncorsink://join/WX7Y9Z',
      );
    });
  });

  group('ShareLinks.inviteShareText', () {
    test('includes code, universal link, and store CTA', () {
      final text = ShareLinks.inviteShareText(
        inviteCode: 'abc123',
        fromUsername: 'pat',
      );
      expect(text, contains('ABC123'));
      expect(text, contains('https://play.syncorsink.app/join/ABC123'));
      expect(text, contains('apps.apple.com'));
      expect(text, contains('@pat'));
    });

    test('falls back to generic "A friend" when username is missing', () {
      final text = ShareLinks.inviteShareText(inviteCode: 'abc123');
      expect(text, startsWith('A friend'));
    });
  });

  group('ShareLinks.momentShareText', () {
    test('includes score, prompt, and both store CTAs', () {
      final text = ShareLinks.momentShareText(
        fromUsername: 'pat',
        totalScore: 840,
        promptText: 'Your face: eat sushi',
      );
      expect(text, contains('@pat'));
      expect(text, contains('840 pts'));
      expect(text, contains('eat sushi'));
      expect(text, contains('apps.apple.com'));
      expect(text, contains('play.google.com'));
    });

    test('omits score clause when score is null', () {
      final text = ShareLinks.momentShareText(
        fromUsername: 'pat',
        promptText: 'Your face: something',
      );
      expect(text, isNot(contains('pts in Sync or Sink')));
    });
  });
}
