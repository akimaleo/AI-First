import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/initialization_provider.dart';
import 'router/app_router.dart';
import 'shared/services/deep_link_service.dart';

class SyncOrSinkApp extends ConsumerStatefulWidget {
  const SyncOrSinkApp({super.key});

  @override
  ConsumerState<SyncOrSinkApp> createState() => _SyncOrSinkAppState();
}

class _SyncOrSinkAppState extends ConsumerState<SyncOrSinkApp> {
  bool _deepLinksStarted = false;

  void _startDeepLinks() {
    if (_deepLinksStarted) return;
    _deepLinksStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final router = ref.read(appRouterProvider);
      ref.read(deepLinkServiceProvider).start(router);
    });
  }

  static final _theme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF6C5CE7),
      brightness: Brightness.light,
    ),
    useMaterial3: true,
  );

  static final _darkTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF6C5CE7),
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  );

  @override
  Widget build(BuildContext context) {
    final init = ref.watch(initializationProvider);

    return init.when(
      loading: () => MaterialApp(
        title: 'Sync or Sink',
        theme: _theme,
        darkTheme: _darkTheme,
        themeMode: ThemeMode.system,
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      error: (error, _) => MaterialApp(
        title: 'Sync or Sink',
        theme: _theme,
        darkTheme: _darkTheme,
        themeMode: ThemeMode.system,
        home: Scaffold(
          body: Center(
            child: Text('Failed to initialize: $error'),
          ),
        ),
      ),
      data: (_) {
        _startDeepLinks();
        final router = ref.watch(appRouterProvider);

        return MaterialApp.router(
          title: 'Sync or Sink',
          theme: _theme,
          darkTheme: _darkTheme,
          themeMode: ThemeMode.system,
          routerConfig: router,
        );
      },
    );
  }
}
