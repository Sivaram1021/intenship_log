import com.android.build.api.dsl.ApplicationExtension

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

configure<ApplicationExtension> {
    namespace = "com.example.intenship_log"
    compileSdk = 36 // ✅ Compiles against Android 16 (SDK 36) to bypass checkDebugAarMetadata errors

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    // ✅ Modern task-based compilerOptions block avoids jvmTarget compilation failures
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinJvmCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8)
        }
    }

    defaultConfig {
        applicationId = "com.example.intenship_log"
        minSdk = flutter.minSdkVersion
        targetSdk = 36 // ✅ Matches targetSdk with compileSdk
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.1.0"))
    implementation("com.google.firebase:firebase-analytics")
}