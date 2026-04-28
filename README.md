# Vault Messenger

An end-to-end encrypted chat app built with Flutter and Firebase.

## Tech Stack
- **Flutter** — cross-platform mobile UI
- **Firebase Auth** — email/password authentication
- **Firestore** — real-time message sync
- **RSA-2048** — key exchange
- **AES-256-CBC** — message encryption

## Setup

1. Clone the repo
```bash
   git clone https://github.com/YOUR_USERNAME/vault-messenger.git
   cd vault-messenger
```

2. Add your Firebase config in `lib/firebase_config.dart`

3. Place `google-services.json` in `android/app/`

4. Install dependencies and run
```bash
   flutter pub get
   flutter run
```
