plugins {
    alias(libs.plugins.android.application)
}

android {
    namespace = "com.draskint.finanzas"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.draskint.finanzas"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "0.1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }
}
