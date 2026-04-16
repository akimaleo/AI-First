/// App-level constants + helpers for building shareable URLs. Centralised so
/// the share card, share sheet copy, and deep-link router stay in sync.
class ShareLinks {
  const ShareLinks._();

  static const String scheme = 'syncorsink';
  static const String universalHost = 'play.syncorsink.app';

  static const String appStoreUrl =
      'https://apps.apple.com/app/sync-or-sink/id0000000000';
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=app.syncorsink';

  /// Universal HTTPS invite link — opens the app when installed via the
  /// Android App Links / iOS Universal Links config, and falls back to a web
  /// landing page (with store CTAs) for recipients without the app.
  static String inviteLink(String inviteCode) {
    final code = inviteCode.trim().toUpperCase();
    return 'https://$universalHost/join/$code';
  }

  /// Custom-scheme invite link. Useful when we want an intent that never
  /// leaves the device through a browser (e.g. clipboard).
  static String inviteDeepLink(String inviteCode) {
    final code = inviteCode.trim().toUpperCase();
    return '$scheme://join/$code';
  }

  /// Copy blob used when share sheet is invoked with no card image (pure
  /// invite). Keeps invite code, universal link, and a store CTA together.
  static String inviteShareText({
    required String inviteCode,
    String? fromUsername,
  }) {
    final code = inviteCode.trim().toUpperCase();
    final who = fromUsername != null && fromUsername.trim().isNotEmpty
        ? '@${fromUsername.trim()}'
        : 'A friend';
    return '$who challenged you to Sync or Sink!\n'
        'Code: $code\n'
        '${inviteLink(code)}\n\n'
        'Get the app: $appStoreUrl';
  }

  /// Copy blob attached to a share-card PNG. Includes score context + store
  /// CTA so recipients who see the text preview know how to install.
  static String momentShareText({
    String? fromUsername,
    int? totalScore,
    required String promptText,
  }) {
    final who = fromUsername != null && fromUsername.trim().isNotEmpty
        ? '@${fromUsername.trim()}'
        : 'I';
    final scoreLine = totalScore != null
        ? '$who scored $totalScore pts in Sync or Sink!'
        : '$who played Sync or Sink!';
    return '$scoreLine\n"$promptText"\n\nPlay on iOS: $appStoreUrl\n'
        'Play on Android: $playStoreUrl';
  }
}
