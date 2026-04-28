# 🔐 Vault Flutter + Firebase

End-to-end encrypted messenger — Flutter frontend + Firebase Auth + Firestore backend.

## Quick Start

### 1. Fill in Firebase config
Open `lib/firebase_config.dart` and replace placeholder values with your project's values from:
**Firebase Console → Project Settings → General → Your apps**

Also place `google-services.json` in `android/app/`.

### 2. Enable Firebase services
- **Authentication** → Enable Email/Password
- **Firestore** → Create database (production mode)

### 3. Deploy security rules
```bash
npm i -g firebase-tools
firebase login
firebase deploy --only firestore:rules,firestore:indexes
```

### 4. Run
```bash
flutter pub get
flutter run
```

---

## Architecture

```
lib/
├── main.dart                  Firebase.initializeApp() + ProviderScope
├── firebase_config.dart       ← PUT YOUR CONFIG HERE
├── services/
│   ├── firebase_service.dart  Auth, Firestore reads/writes, Secure Storage
│   ├── auth_service.dart      Riverpod auth state + register/login logic
│   └── messaging_service.dart Real-time message streams + send + decrypt
├── screens/
│   ├── auth_screen.dart       Login / Register
│   ├── contacts_screen.dart   Conversation list (live Firestore stream)
│   └── chat_screen.dart       Real-time chat (live Firestore stream)
├── crypto/vault_crypto.dart   RSA-2048 + AES-256-CBC (pure Dart, no bridge)
├── widgets/vault_widgets.dart Shared UI: Avatar, Bubbles, ComposeBar, Modal
├── navigation/router.dart     GoRouter + Firebase auth guard
└── theme/app_theme.dart       Dark theme, colors, typography
```

## Firestore Schema

```
users/{uid}
  displayName, username, publicKey (RSA), createdAt, fcmToken

conversations/{uid1_uid2}
  participants[], lastMessage, lastMessageAt

conversations/{id}/messages/{msgId}
  senderId, text, ciphertext (AES-256), iv, encrypted, readOnly, status, timestamp
```

**AES session keys and RSA private keys never touch Firestore — device Keychain only.**

## Security Rules
See `firestore.rules` — enforces participant-only access, append-only messages, senderId validation.
