import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sync_or_sink/features/capture/share_moment_card.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Center(child: SizedBox(width: 360, child: child)),
    ),
  );
}

void main() {
  testWidgets('ShareMomentCard renders prompt, score, and rounds overlay',
      (tester) async {
    final data = ShareCardData(
      modifiedImagePath: 'https://cdn.example.com/fake.png',
      prompt: 'Your face: "eat sushi"',
      usedFallback: false,
      capturedAt: DateTime(2026, 4, 16),
      gameContext: const GameMomentContext(
        promptText: 'Your face: "eat sushi"',
        totalScore: 840,
        totalRounds: 10,
      ),
      author: const ShareAuthor(username: 'sushigamer'),
    );

    await tester.pumpWidget(_wrap(ShareMomentCard(data: data)));
    await tester.pump();

    expect(find.text('Sync or Sink'), findsOneWidget);
    expect(find.text('840 pts'), findsOneWidget);
    expect(find.text('10 rounds'), findsOneWidget);
    expect(find.textContaining('eat sushi'), findsOneWidget);
    expect(find.text('@sushigamer'), findsOneWidget);
    expect(find.text('Play free on iOS + Android'), findsOneWidget);
    // Fallback chip should not show when AI succeeded.
    expect(find.text('AI unavailable'), findsNothing);
  });

  testWidgets('ShareMomentCard uses displayName when provided',
      (tester) async {
    final data = ShareCardData(
      modifiedImagePath: 'https://cdn.example.com/fake.png',
      prompt: 'prompt',
      usedFallback: false,
      capturedAt: DateTime(2026, 4, 16),
      author: const ShareAuthor(
        username: 'sushigamer',
        displayName: 'Sushi Gamer',
      ),
    );

    await tester.pumpWidget(_wrap(ShareMomentCard(data: data)));
    await tester.pump();

    expect(find.text('Sushi Gamer'), findsOneWidget);
    expect(find.text('@sushigamer'), findsNothing);
  });

  testWidgets('ShareMomentCard hides author row when unknown',
      (tester) async {
    final data = ShareCardData(
      modifiedImagePath: 'https://cdn.example.com/fake.png',
      prompt: 'prompt',
      usedFallback: false,
      capturedAt: DateTime(2026, 4, 16),
    );

    await tester.pumpWidget(_wrap(ShareMomentCard(data: data)));
    await tester.pump();

    // Still shows CTA even without an author handle.
    expect(find.text('Play free on iOS + Android'), findsOneWidget);
    // No handle text means no '@' prefix leaks through.
    expect(find.textContaining('@'), findsNothing);
  });

  testWidgets('ShareMomentCard labels fallback when AI unavailable',
      (tester) async {
    final data = ShareCardData(
      modifiedImagePath: 'https://cdn.example.com/fake.png',
      prompt: 'Your face: "eat sushi"',
      usedFallback: true,
      capturedAt: DateTime(2026, 4, 16),
      gameContext: const GameMomentContext(
        promptText: 'Your face: "eat sushi"',
        totalScore: 250,
        totalRounds: 10,
      ),
    );

    await tester.pumpWidget(_wrap(ShareMomentCard(data: data)));
    await tester.pump();

    expect(find.text('AI unavailable'), findsOneWidget);
  });

  testWidgets('ShareMomentCard falls back to prompt when no game context',
      (tester) async {
    final data = ShareCardData(
      modifiedImagePath: 'https://cdn.example.com/fake.png',
      prompt: 'freeform moment',
      usedFallback: false,
      capturedAt: DateTime(2026, 4, 16),
    );

    await tester.pumpWidget(_wrap(ShareMomentCard(data: data)));
    await tester.pump();

    expect(find.textContaining('freeform moment'), findsOneWidget);
    expect(find.textContaining('pts'), findsNothing);
  });
}
