import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'share_links.dart';

final appLinksProvider = Provider<AppLinks>((ref) => AppLinks());

/// Listens for `syncorsink://` custom-scheme links and
/// `https://play.syncorsink.app/*` universal links, and forwards them into
/// the GoRouter. Exposed as a ChangeNotifier-less service so the app can
/// start the listener once the router is available.
class DeepLinkService {
  DeepLinkService(this._appLinks);

  final AppLinks _appLinks;
  StreamSubscription<Uri>? _subscription;

  /// Starts listening to link events. Calling `start` twice is a no-op — the
  /// existing subscription is reused. Any inbound link is mapped to a route
  /// on [router] via [mapUriToRoute].
  Future<void> start(GoRouter router) async {
    if (_subscription != null) return;

    final initial = await _appLinks.getInitialLink();
    if (initial != null) {
      _dispatch(router, initial);
    }

    _subscription = _appLinks.uriLinkStream.listen(
      (uri) => _dispatch(router, uri),
      onError: (_) {},
    );
  }

  void _dispatch(GoRouter router, Uri uri) {
    final route = mapUriToRoute(uri);
    if (route != null) router.go(route);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  /// Pure function for tests: converts an inbound deep link to a GoRouter
  /// location. Returns `null` when the link is not one we handle.
  static String? mapUriToRoute(Uri uri) {
    final isCustomScheme = uri.scheme == ShareLinks.scheme;
    final isUniversal =
        uri.scheme == 'https' && uri.host == ShareLinks.universalHost;
    if (!isCustomScheme && !isUniversal) return null;

    final segments = uri.pathSegments;

    // syncorsink://join/<code> — custom scheme: first segment is host, rest is
    // path. app_links delivers this as host='join', pathSegments=[<code>].
    if (isCustomScheme && uri.host == 'join') {
      final code = segments.isNotEmpty ? segments.first : null;
      if (code != null && code.isNotEmpty) {
        return '/join/${code.toUpperCase()}';
      }
    }

    // https://play.syncorsink.app/join/<code>
    if (isUniversal && segments.length >= 2 && segments[0] == 'join') {
      final code = segments[1];
      if (code.isNotEmpty) return '/join/${code.toUpperCase()}';
    }

    return null;
  }
}

final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  final service = DeepLinkService(ref.watch(appLinksProvider));
  ref.onDispose(service.dispose);
  return service;
});
