plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter plugin MUST come after Android and Kotlin plugins
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.shift_app"

    // ✅ Force modern SDK versions (fixes Android BLE + permission stability)
    compileSdk = 34

    defaultConfig {
        applicationId = "com.example.shift_app"

        // ✅ Minimum required for BLE support (21 = Android 5.0, required for BLE)
        minSdk = flutter.minSdkVersion

        // ✅ Required for Android 12+ BLE permissions to work properly
        targetSdk = 34

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    compileOptions {
        // Required for modern Flutter + plugin compatibility
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    buildTypes {
        release {
            // Using debug signing for now (fine for testing)
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
