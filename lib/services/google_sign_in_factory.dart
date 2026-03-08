import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';

const String _googleSignInClientId = String.fromEnvironment(
  'GOOGLE_SIGN_IN_CLIENT_ID',
);

bool isGoogleSignInConfiguredForCurrentPlatform() {
  if (!Platform.isMacOS) {
    return true;
  }
  return _googleSignInClientId.trim().isNotEmpty;
}

void ensureGoogleSignInConfiguredForCurrentPlatform() {
  if (isGoogleSignInConfiguredForCurrentPlatform()) {
    return;
  }
  throw StateError(
    'Google Sign-In is not configured for macOS. '
    'Provide --dart-define=GOOGLE_SIGN_IN_CLIENT_ID=<macOS OAuth client id>.',
  );
}

GoogleSignIn createGoogleSignIn({required List<String> scopes}) {
  final trimmedClientId = _googleSignInClientId.trim();
  if (Platform.isMacOS && trimmedClientId.isNotEmpty) {
    return GoogleSignIn(
      clientId: trimmedClientId,
      scopes: scopes,
    );
  }

  return GoogleSignIn(scopes: scopes);
}
