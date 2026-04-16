import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sync_or_sink/app.dart';

void main() {
  // NOTE: App-level rendering requires a booted Supabase client. Until the
  // test harness mocks Supabase.initialize, this is skipped. The Capture the
  // Moment flow is covered by capture_pipeline_test.dart /
  // share_moment_card_test.dart without needing that bootstrap.
  testWidgets(
    'App renders home screen',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: SyncOrSinkApp()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sync or Sink'), findsWidgets);
      expect(find.text('Solo Play'), findsOneWidget);
    },
    skip: true,
  );
}
