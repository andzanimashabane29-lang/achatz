# A-Chatz implementation notes

## Architecture

The project uses feature-first folders with Clean Architecture direction:

- `domain`: pure models and entities.
- `data`: Firebase repositories and data sources.
- `providers`: Riverpod dependency injection and state.
- `presentation`: Flutter UI screens and widgets.

For a bigger production codebase, split repositories into interfaces and implementations:

```txt
domain/repositories/chat_repository_contract.dart
data/repositories/firebase_chat_repository.dart
application/controllers/chat_controller.dart
```

## Feature coverage included

Included:
- Premium dark UI shell
- Onboarding
- Login/register with Firebase Auth
- Presence update method
- Real-time chat list
- Real-time message stream
- Send text messages
- Group schema
- Edit/delete/react methods
- Status UI foundation
- Audio/video call UI foundation
- Profile/privacy UI foundation
- Firestore rules
- Storage rules
- FCM token storage
- Cloud Functions notifications

Still to complete:
- Full phone OTP screen flow
- Full media picker/upload UI
- Full status story playback
- Real calls engine
- Contacts discovery
- Search indexing
- End-to-end encryption
- Advanced moderation dashboard
