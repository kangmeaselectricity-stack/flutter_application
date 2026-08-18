plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // 🎯 កំណត់ Namespace ទៅតាមឈ្មោះកញ្ចប់កម្មវិធីរបស់បង (ដូរ example ចេញបើមាន)
    namespace = "com.example.flutter_application"
    
    // 🎯 ដំណោះស្រាយ៖ ដំឡើងទៅ 36 ដើម្បីឱ្យត្រូវគ្នាជាមួយបណ្តា Plugins ទាំងអស់ (camera, geolocator, etc.)
    compileSdk = 36

    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        // 🎯 កំណត់ Application ID របស់បង
        applicationId = "com.example.flutter_application"
        
        // ជំនាន់ Android ទាបបំផុតដែលអាចដំឡើង App នេះបាន (ជាទូទៅគឺ ២១ ឡើងទៅ)
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // 🎯 កំណត់បើក Minify (R8) និងហៅប្រើ proguard-rules.pro ដែលបានបង្កើតពីមុន
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// =============================================================================
// 🎯 ដំណោះស្រាយស្នូល៖ ប្រើប្រព័ន្ធ Gradle 8.x ដើម្បីបង្ខំបញ្ចូល androidx.core ជំនាន់ខ្ពស់
// វាជួយផ្គត់ផ្គង់ attribute 'lStar' ទៅឱ្យ google_mlkit_commons ភ្លាមៗ ដោយមិនលោត Error "Too late"
// =============================================================================
