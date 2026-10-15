import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.jadwal.jadwal_v2"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.jadwal.jadwal_v2"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        // ── سياسة التوقيع الإلزامية ──────────────────────────────────────────
        // لا يوجد "توقيع افتراضي" أو بديل: إما التوقيع الرسمي المحدد أدناه،
        // أو يتوقف البناء بخطأ صريح. لا يُقبل أبداً توقيع debug كإصدار.
        val keystorePropertiesFile = rootProject.file("key.properties")
        val keystoreProperties = Properties()
        var hasValidPropertiesFile = false

        // 1. محلياً: android/key.properties (غير متتبَّع في Git)
        if (keystorePropertiesFile.exists()) {
            keystoreProperties.load(FileInputStream(keystorePropertiesFile))
            val storeFileProp = keystoreProperties["storeFile"] as String?
            val storePasswordProp = keystoreProperties["storePassword"] as String?
            val keyAliasProp = keystoreProperties["keyAlias"] as String?
            val keyPasswordProp = keystoreProperties["keyPassword"] as String?

            if (!storeFileProp.isNullOrBlank() && !storePasswordProp.isNullOrBlank() && !keyAliasProp.isNullOrBlank() && !keyPasswordProp.isNullOrBlank()) {
                hasValidPropertiesFile = true
            }
        }

        // 2. CI/CD: متغيرات البيئة القادمة من أسرار GitHub Actions
        val envStoreFile = System.getenv("STORE_FILE")
        val envStorePassword = System.getenv("STORE_PASSWORD")
        val envKeyAlias = System.getenv("KEY_ALIAS")
        val envKeyPassword = System.getenv("KEY_PASSWORD")

        val hasValidEnvVars = !envStoreFile.isNullOrBlank() && !envStorePassword.isNullOrBlank() && !envKeyAlias.isNullOrBlank() && !envKeyPassword.isNullOrBlank()

        // مصدر التوقيع الرسمي الوحيد المسموح به
        val signingStoreFile: File? = when {
            hasValidPropertiesFile -> file(keystoreProperties["storeFile"] as String)
            hasValidEnvVars -> file(envStoreFile!!)
            else -> null
        }

        val signingStorePassword: String? = when {
            hasValidPropertiesFile -> keystoreProperties["storePassword"] as String
            hasValidEnvVars -> envStorePassword
            else -> null
        }
        val signingKeyAlias: String? = when {
            hasValidPropertiesFile -> keystoreProperties["keyAlias"] as String
            hasValidEnvVars -> envKeyAlias
            else -> null
        }
        val signingKeyPassword: String? = when {
            hasValidPropertiesFile -> keystoreProperties["keyPassword"] as String
            hasValidEnvVars -> envKeyPassword
            else -> null
        }

        // لا نسمح ببناء release بتوقيع غير محدد: المهمة تُجهَض قبل بدء أي عمل.
        val releaseTaskRequested = gradle.startParameter.taskNames.any {
            it.contains("release", ignoreCase = true)
        }
        val unsignedVerificationAllowed =
            System.getenv("JADWAL_ALLOW_UNSIGNED_VERIFICATION").equals("true", ignoreCase = true)

        if (signingStoreFile == null) {
            if (releaseTaskRequested && !unsignedVerificationAllowed) {
                throw GradleException(
                    """
                    |❌ البناء مرفوض: توقيع الإصدار الرسمي غير محدد.
                    |
                    |لم يتم العثور على توقيع رسمي صالح. يلزم توفير أحد المصدرين التاليين فقط:
                    |  1) ملف android/key.properties يحتوي: storeFile, storePassword, keyAlias, keyPassword
                    |  2) متغيرات البيئة: STORE_FILE, STORE_PASSWORD, KEY_ALIAS, KEY_PASSWORD
                    |
                    |ممنوع إنتاج APK/AAB للإصدار بتوقيع debug أو بدون توقيع.
                    |لبناء تحقّق debug غير موقّع (CI من fork بدون أسرار) مرّر صراحةً:
                    |  JADWAL_ALLOW_UNSIGNED_VERIFICATION=true
                    """.trimMargin()
                )
            }
            // مسار debug التحقّقي فقط: لا يُنشأ توقيع release إطلاقاً.
            println("[jadwal-signing] ⚠️ لا يوجد توقيع رسمي — مسموح بمسار debug التحقّقي فقط (بدون إصدار).")
        } else {
            // تحقّق مبكّر: الملف موجود وغير فارغ، وإلا فشل البناء برسالة واضحة
            // بدل خطأ AGP المبهم "storeFile ... does not exist" أو "keystore password was incorrect".
            if (!signingStoreFile.exists() || signingStoreFile.length() == 0L) {
                throw GradleException(
                    "❌ البناء مرفوض: ملف التوقيع الرسمي غير موجود أو فارغ: ${signingStoreFile.absolutePath}"
                )
            }

            create("release") {
                storeFile = signingStoreFile
                storePassword = signingStorePassword
                keyAlias = signingKeyAlias
                keyPassword = signingKeyPassword
                // مخططات التوقيع الحديثة إلزامية حتى لا يُنتَج إصدار بتوقيع v1 فقط.
                // (أسماء الخصائص كما في AGP 8.6: ApkSigningConfig.enableV{1..4}Signing)
                enableV1Signing = true
                enableV2Signing = true
                enableV3Signing = true
                enableV4Signing = true
            }
            println("[jadwal-signing] ✅ التوقيع الرسمي مُحمَّل: alias=${signingKeyAlias}, store=${signingStoreFile.name}")
        }
    }

    buildTypes {
        release {
            // يرتبط الإصدار بالتوقيع الرسمي حصراً؛ إن لم يُنشأ التوقيع (مسار debug
            // التحقّقي) تبقى المهمة release بلا توقيع ويفشل التجميع بدل تمرير نسخة مزيفة.
            val officialSigning = signingConfigs.findByName("release")
            if (officialSigning != null) {
                signingConfig = officialSigning
            }
        }
    }
}

flutter {
    source = "../.."
}

// 🚨 هذا هو الجزء الجديد لإجبار المكتبات على التوافق مع AGP 8.6.0
configurations.all {
    resolutionStrategy {
        force("androidx.browser:browser:1.8.0")
        force("androidx.core:core-ktx:1.13.1")
        force("androidx.core:core:1.13.1")
    }
}
