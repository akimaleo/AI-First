import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/services/firestore_service.dart';

/// Performs all async startup work (Firebase, auth, seeding) inside the widget
/// tree so `runApp()` is called immediately and the user never sees a black
/// screen. Consumed by the root app widget via `ref.watch`.
final initializationProvider = FutureProvider<void>((ref) async {
  // Firebase is the sole backend after the GUSAA-50 Supabase removal. Native
  // config comes from android/app/google-services.json (gitignored; written by
  // CI from the GOOGLE_SERVICES_JSON_BASE64 secret). If the file is absent on
  // a dev machine the try/catch keeps the app bootable for UI-only work.
  var firebaseReady = false;
  try {
    await Firebase.initializeApp();
    firebaseReady = true;
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('Firebase.initializeApp() skipped: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // Anonymous auth — every client gets a stable uid. Board owner chose
  // anonymous-only auth for the MVP.
  if (firebaseReady && FirebaseAuth.instance.currentUser == null) {
    try {
      await FirebaseAuth.instance
          .signInAnonymously()
          .timeout(const Duration(seconds: 15));
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('FirebaseAuth.signInAnonymously() failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  // Seed the challenges collection on first run so the game is playable
  // immediately without manual Firestore console work.
  if (firebaseReady) {
    try {
      final service = FirestoreService(
        FirebaseFirestore.instance,
        FirebaseAuth.instance,
      );
      await service
          .seedChallengesIfEmpty()
          .timeout(const Duration(seconds: 10));
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Challenge seeding failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }
});
