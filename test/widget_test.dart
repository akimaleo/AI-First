import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sync_or_sink/app.dart';

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: SyncOrSinkApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sync or Sink'), findsWidgets);
    expect(find.text('Play'), findsOneWidget);
  });

  testWidgets('Play button navigates to game screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: SyncOrSinkApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();

    expect(find.text('Would You Rather'), findsOneWidget);
  });
}
