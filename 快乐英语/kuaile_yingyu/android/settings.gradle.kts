import org.gradle.api.initialization.resolve.RepositoriesMode

pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        // 阿里云镜像优先（国内网络下官方仓库不稳定），官方仓库兜底
        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        // 显式用 dl.google.com 替代 google()：maven.google.com 在当前网络下 SSL 握手超时
        maven { url = uri("https://dl.google.com/dl/android/maven2/") }
        mavenCentral()
        gradlePluginPortal()
    }
}

// Gradle 9 / Flutter 3.47 起，插件子构建（includeBuild flutter_tools/gradle）
// 使用 FAIL_ON_PROJECT_REPOS，禁止在 project 里声明仓库。
// 因此依赖仓库统一在 settings 中声明（PREFER_SETTINGS），build.gradle.kts 里不再有 allprojects.repositories。
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://dl.google.com/dl/android/maven2/") }
        // Flutter engine 的 embedding 构件只发布在这里，各 Maven 镜像都没有
        maven {
            url = uri("https://storage.googleapis.com/download.flutter.io")
            content {
                includeGroup("io.flutter")
                includeGroup("io.flutter.arm64_v8a_debug")
                includeGroup("io.flutter.armeabi_v7a_debug")
                includeGroup("io.flutter.x86_64_debug")
            }
        }
        mavenCentral()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
}

include(":app")
