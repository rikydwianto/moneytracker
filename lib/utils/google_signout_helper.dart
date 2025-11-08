import 'package:google_sign_in/google_sign_in.dart';

Future<void> signOutGoogleIfNeeded() async {
  try {
    final googleSignIn = GoogleSignIn();
    final isSignedIn = await googleSignIn.isSignedIn();
    if (isSignedIn) {
      await googleSignIn.signOut();
    }
  } catch (e) {
    // Ignore errors, fallback to Firebase signOut
  }
}
