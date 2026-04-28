
import 'package:firebase_core/firebase_core.dart';

class VaultFirebaseConfig {
  // ── Replace these with your actual Firebase project values ──
  static const apiKey            = 'YOUR_API_KEY';
  static const appId             = 'YOUR_APP_ID';
  static const messagingSenderId = 'YOUR_MESSAGING_SENDER_ID';
  static const projectId         = 'YOUR_PROJECT_ID';
  static const storageBucket     = 'YOUR_PROJECT_ID.appspot.com';

  static FirebaseOptions get androidOptions => const FirebaseOptions(
    apiKey:            apiKey,
    appId:             appId,
    messagingSenderId: messagingSenderId,
    projectId:         projectId,
    storageBucket:     storageBucket,
  );

  static FirebaseOptions get iosOptions => const FirebaseOptions(
    apiKey:            apiKey,
    appId:             appId,           // Use the iOS App ID from Firebase console
    messagingSenderId: messagingSenderId,
    projectId:         projectId,
    storageBucket:     storageBucket,
    iosClientId:       'YOUR_IOS_CLIENT_ID',   // from GoogleService-Info.plist
    iosBundleId:       'com.vault.vaultFlutter',
  );
}
