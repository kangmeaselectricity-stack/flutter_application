// ⚙️ ហ្វាល់នេះត្រូវបានបង្កើតដោយដៃ ផ្ទៀងផ្ទាត់ជាមួយ google-services.json
// Project: meter-reading-654c0

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions មិនត្រូវបានកំណត់សម្រាប់ platform នេះទេ',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCcBX03QM3EbUKqeCA0Pekzp4nLqcJgsO4',
    appId: '1:634280687089:android:3c1f7b9209fbf6b8764050',
    messagingSenderId: '634280687089',
    projectId: 'meter-reading-654c0',
    databaseURL: 'https://meter-reading-654c0-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'meter-reading-654c0.firebasestorage.app',
  );

  // ⚠️ iOS: ត្រូវទាញ GoogleService-Info.plist ថ្មី ហើយ update តម្លៃដែលទទេៗ
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCcBX03QM3EbUKqeCA0Pekzp4nLqcJgsO4',
    appId: '1:634280687089:ios:000000000000000000000000', // ⚠️ ចាំ update ពី GoogleService-Info.plist
    messagingSenderId: '634280687089',
    projectId: 'meter-reading-654c0',
    databaseURL: 'https://meter-reading-654c0-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'meter-reading-654c0.firebasestorage.app',
    iosClientId: '', // ⚠️ ចាំ update ពី GoogleService-Info.plist
    iosBundleId: 'com.example.flutterApplication',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCcBX03QM3EbUKqeCA0Pekzp4nLqcJgsO4',
    appId: '1:634280687089:web:000000000000000000000000',
    messagingSenderId: '634280687089',
    projectId: 'meter-reading-654c0',
    databaseURL: 'https://meter-reading-654c0-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'meter-reading-654c0.firebasestorage.app',
  );
}
