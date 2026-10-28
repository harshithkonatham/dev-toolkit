# Mobile Frameworks — Setup & Reference

Updated: April 2026

---

## React Native 0.77 + Expo SDK 52

**Best for**: Cross-platform iOS & Android with JavaScript/TypeScript.

### Expo (Recommended for new projects)

```bash
npx create-expo-app@latest my-app --template
cd my-app

# Start dev server
npx expo start

# Run on device
npx expo start --ios
npx expo start --android

# Build for production (EAS)
npm install -g eas-cli
eas build --platform ios
eas build --platform android
```

**Project structure**:
```
my-app/
├── app/                    # Expo Router (file-based routing)
│   ├── _layout.tsx         # Root layout
│   ├── index.tsx           # Home screen
│   ├── (tabs)/
│   │   ├── _layout.tsx     # Tab navigator
│   │   ├── home.tsx
│   │   └── profile.tsx
│   └── [id].tsx            # Dynamic route
├── components/
├── hooks/
├── constants/
├── assets/
├── app.json
└── package.json
```

**Expo Router** (file-based navigation):
```typescript
// app/(tabs)/_layout.tsx
import { Tabs } from 'expo-router'
import { Ionicons } from '@expo/vector-icons'

export default function TabLayout() {
  return (
    <Tabs>
      <Tabs.Screen
        name="home"
        options={{
          title: 'Home',
          tabBarIcon: ({ color }) => <Ionicons name="home" color={color} size={24} />
        }}
      />
      <Tabs.Screen
        name="profile"
        options={{
          title: 'Profile',
          tabBarIcon: ({ color }) => <Ionicons name="person" color={color} size={24} />
        }}
      />
    </Tabs>
  )
}
```

**`app.json` config**:
```json
{
  "expo": {
    "name": "My App",
    "slug": "my-app",
    "version": "1.0.0",
    "orientation": "portrait",
    "icon": "./assets/icon.png",
    "splash": {
      "image": "./assets/splash.png",
      "backgroundColor": "#000000"
    },
    "ios": {
      "bundleIdentifier": "com.myco.myapp",
      "supportsTablet": true
    },
    "android": {
      "package": "com.myco.myapp",
      "adaptiveIcon": {
        "foregroundImage": "./assets/adaptive-icon.png",
        "backgroundColor": "#000000"
      }
    },
    "plugins": ["expo-router"]
  }
}
```

### Essential Expo packages

```bash
# Navigation
npx expo install expo-router react-native-safe-area-context react-native-screens

# UI
npx expo install @expo/vector-icons expo-linear-gradient expo-blur

# Storage
npx expo install expo-secure-store @react-native-async-storage/async-storage

# Media
npx expo install expo-camera expo-image-picker expo-media-library

# Notifications
npx expo install expo-notifications

# Auth
npx expo install expo-auth-session expo-web-browser

# Gestures & Animations
npx expo install react-native-gesture-handler react-native-reanimated

# Maps
npx expo install react-native-maps expo-location
```

---

### Bare React Native (without Expo)

```bash
npx @react-native-community/cli@latest init MyApp --template react-native-template-typescript
cd MyApp

# iOS
npx pod-install
npx react-native run-ios

# Android
npx react-native run-android
```

---

## Flutter 3.29

**Best for**: Beautiful cross-platform UIs, native performance, single codebase.

### Setup

```bash
# Install Flutter SDK
brew install flutter    # macOS via Homebrew
# OR download from https://flutter.dev/docs/get-started/install

# Check setup
flutter doctor

# Create project
flutter create my_app --org com.myco
cd my_app

# Run
flutter run

# Run on specific device
flutter run -d iPhone    # iOS simulator
flutter run -d emulator  # Android emulator
```

**Project structure**:
```
my_app/
├── lib/
│   ├── main.dart
│   ├── screens/
│   │   ├── home_screen.dart
│   │   └── profile_screen.dart
│   ├── widgets/
│   │   └── custom_button.dart
│   ├── models/
│   ├── services/
│   └── providers/
├── android/
├── ios/
├── pubspec.yaml
└── test/
```

**`lib/main.dart`**:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: HomeScreen(),
    );
  }
}
```

**`pubspec.yaml` dependencies**:
```yaml
dependencies:
  flutter:
    sdk: flutter

  # State management
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

  # Navigation
  go_router: ^14.2.7

  # HTTP
  dio: ^5.4.3+1
  retrofit: ^4.1.0

  # Local storage
  hive_flutter: ^1.1.0
  shared_preferences: ^2.2.3

  # UI
  cached_network_image: ^3.3.1
  flutter_svg: ^2.0.10+1
  lottie: ^3.1.2

  # Auth
  firebase_auth: ^4.19.4
  google_sign_in: ^6.2.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  riverpod_generator: ^2.4.0
  build_runner: ^2.4.9
```

**GoRouter navigation**:
```dart
final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => HomeScreen(),
      routes: [
        GoRoute(
          path: 'profile/:id',
          builder: (context, state) => ProfileScreen(
            id: state.pathParameters['id']!,
          ),
        ),
      ],
    ),
  ],
);
```

**Riverpod state management**:
```dart
// providers/counter_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'counter_provider.g.dart';

@riverpod
class Counter extends _$Counter {
  @override
  int build() => 0;

  void increment() => state++;
  void decrement() => state--;
}

// In widget:
class CounterWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(counterProvider);
    return Text('$count');
  }
}
```

**Build for production**:
```bash
# iOS
flutter build ios --release

# Android APK
flutter build apk --release

# Android App Bundle (Play Store)
flutter build appbundle --release

# Web
flutter build web --release
```

---

## UI Component Libraries for React Native

| Library | Best For |
|---|---|
| NativeWind | Tailwind CSS syntax for RN |
| React Native Paper | Material Design |
| Gluestack UI | Universal UI components |
| Tamagui | Cross-platform, performance |
| Shoutem UI | Component library |

**NativeWind setup**:
```bash
npm install nativewind tailwindcss
npx tailwindcss init

# babel.config.js — add preset: 'nativewind/babel'
```

```typescript
// Usage
<View className="flex-1 items-center justify-center bg-white">
  <Text className="text-2xl font-bold text-blue-600">Hello</Text>
  <Pressable className="mt-4 px-6 py-3 bg-blue-500 rounded-full">
    <Text className="text-white font-semibold">Press me</Text>
  </Pressable>
</View>
```

---

## State Management for Mobile

| Library | Framework | When to Use |
|---|---|---|
| Zustand | React Native | Simple global state |
| TanStack Query | React Native | Server state, API caching |
| Redux Toolkit | React Native | Complex state, large apps |
| Jotai | React Native | Atomic state |
| Riverpod | Flutter | Flutter recommended |
| BLoC / Cubit | Flutter | Event-driven state |
| GetX | Flutter | All-in-one (state + routes) |

---

## Push Notifications

### Expo Notifications
```bash
npx expo install expo-notifications
```

```typescript
import * as Notifications from 'expo-notifications'

async function registerForPush() {
  const { status } = await Notifications.requestPermissionsAsync()
  if (status !== 'granted') return

  const token = await Notifications.getExpoPushTokenAsync({
    projectId: 'your-project-id'
  })
  return token.data
}
```

### Firebase Cloud Messaging (FCM)
```bash
npx expo install @react-native-firebase/app @react-native-firebase/messaging
```

---

## OTA Updates

```bash
# Expo EAS Update (recommended)
npm install expo-updates
eas update --branch production --message "Fix crash"

# CodePush (Microsoft)
npm install react-native-code-push
```

---

## Publishing

### App Store (iOS) via EAS
```bash
eas submit --platform ios
```

### Google Play via EAS
```bash
eas submit --platform android
```

### Flutter
```bash
# Build signed APK/AAB
flutter build appbundle
# Upload via Google Play Console

# iOS — open in Xcode, archive, distribute
open ios/Runner.xcworkspace
```
