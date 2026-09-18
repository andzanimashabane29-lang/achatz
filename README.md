# A-Chatz — Premium Flutter + Firebase Messaging Platform Starter

A-Chatz is an advanced WhatsApp-like mobile app starter built with Flutter, Firebase Authentication, Cloud Firestore, Firebase Storage, Firebase Cloud Functions, Firebase Cloud Messaging, Riverpod, and a Clean Architecture / MVVM-ready structure.

This starter gives you the production foundation: luxury black-and-white UI, auth, real-time chats, group schema, statuses, calls UI, scalable Firestore design, security rules, Cloud Functions notification triggers, and deployment guidance.

## Important reality check

This is a strong production starter, not a finished WhatsApp clone. Real end-to-end encryption, real audio/video calling, moderation operations, and full media workflows require deeper implementation and testing. The message model is **encryption-ready** through `cipherText`, but encryption is not yet implemented.

## Folder structure

```txt
a_chatz/
  lib/
    main.dart
    src/
      app.dart
      core/
        firebase/
        router/
        theme/
      shared/
        widgets/
      features/
        auth/
          data/
          domain/
          providers/
          presentation/
        chat/
          data/
          domain/
          providers/
          presentation/
        status/
        calls/
        profile/
        notifications/
  firebase/
    firestore.rules
    storage.rules
    firestore.indexes.json
    firebase.json
  functions/
    src/index.ts
    package.json
    tsconfig.json
```

## Firestore schema

```txt
users/{uid}
  email
  username
  phoneNumber
  avatarUrl
  bio
  status
  isOnline
  lastSeen
  blockedUserIds[]
  privacy {
    lastSeen: everyone | contacts | nobody
    profilePhoto: everyone | contacts | nobody
    status: everyone | contacts | nobody
  }

users/{uid}/tokens/{fcmToken}

chats/{chatId}
  type: private | group
  title
  photoUrl
  description
  memberIds[]
  admins[]
  permissions {
    onlyAdminsCanSend
    onlyAdminsCanEditInfo
    onlyAdminsCanAddMembers
  }
  typing { uid: true|false }
  mutedBy[]
  archivedBy[]
  pinnedMessageIds[]
  lastMessage
  lastMessageSenderId
  lastMessageAt
  createdBy
  createdAt

chats/{chatId}/messages/{messageId}
  senderId
  type: text | image | video | voice | document | location | system
  cipherText
  mediaUrl
  mediaMeta {}
  replyToMessageId
  forwardOf
  createdAt
  editedAt
  deletedFor[]
  deletedForEveryone
  reactions { uid: emoji }
  deliveredTo { uid: timestamp }
  readBy { uid: timestamp }

statuses/{statusId}
  ownerId
  type: text | image | video
  text
  mediaUrl
  background
  viewerIds[]
  expiresAt
  createdAt

calls/{callId}
  type: audio | video
  participantIds[]
  startedBy
  status: ringing | missed | completed | declined
  startedAt
  endedAt
```

## Firebase setup

1. Create a Firebase project.
2. Install tooling:

```bash
npm install -g firebase-tools
dart pub global activate flutterfire_cli
firebase login
```

3. From the Flutter project root:

```bash
flutterfire configure
flutter pub get
```

The command generates the real `lib/src/core/firebase/firebase_options.dart`. Replace the placeholder file with the generated configuration.

4. Enable Firebase products:
- Authentication: Email/Password and Phone
- Cloud Firestore
- Firebase Storage
- Cloud Messaging
- Cloud Functions

5. Deploy rules and indexes:

```bash
cd firebase
firebase deploy --only firestore:rules,firestore:indexes,storage
```

6. Deploy functions:

```bash
cd ../functions
npm install
npm run build
firebase deploy --only functions
```

## Push notifications

Android:
- Ensure `google-services.json` exists under `android/app/`.
- Keep Firebase Messaging dependency installed.
- Test on a real device or emulator with Google Play services.

iOS:
- Add `GoogleService-Info.plist` in Xcode.
- Enable Push Notifications and Background Modes.
- Upload an APNs authentication key in Firebase Console > Project Settings > Cloud Messaging.

## Run locally

```bash
flutter pub get
flutter run
```

For emulator testing:

```bash
firebase emulators:start --only auth,firestore,storage,functions
```

## Android deployment

```bash
flutter build apk --release
flutter build appbundle --release
```

Upload the `.aab` to Google Play Console.

## iOS deployment

```bash
cd ios
pod install
cd ..
flutter build ios --release
```

Then archive and distribute from Xcode.

## Suggested next build phases

1. Replace `cipherText` placeholder with real client-side encryption.
2. Add image/video/document upload service.
3. Add WebRTC/Agora/Twilio for real calls.
4. Add group admin screens and permission controls.
5. Add status viewer with expiry cleanup Cloud Function.
6. Add moderation dashboard for reports.
7. Add Firestore rule unit tests with Firebase Emulator Suite.
