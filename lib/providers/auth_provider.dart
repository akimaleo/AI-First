import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authStateChangesProvider).asData?.value?.uid ??
      ref.watch(firebaseAuthProvider).currentUser?.uid;
});
