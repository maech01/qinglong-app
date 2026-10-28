#!/usr/bin/env bash
# Build the optimized QingLong client APK.
#
# The project is a 2022-era Flutter app (Dart SDK <3.0.0, AGP 4.1 / Gradle 6.7
# layout). It must be built with Flutter 3.7.x and JDK 11 — newer Flutter
# versions removed the `apply from: flutter.gradle` build script this project
# relies on, and Gradle 6.7 cannot run on JDK 17.
#
# Usage:  ./build_apk.sh
# Output: build/app/outputs/flutter-apk/app-release.apk
set -euo pipefail

cd "$(dirname "$0")"

FLUTTER_MIN="3.7.0"
FLUTTER_MAX="3.8.0"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "缺少命令: $1 — $2" >&2
    exit 1
  }
}

need flutter "请安装 Flutter 3.7.x：https://docs.flutter.dev/release/archive"
need java "请安装 JDK 11 并设置 JAVA_HOME"

FLUTTER_VER="$(flutter --version 2>/dev/null | head -1 | awk '{print $2}')"
echo "==> Flutter: $FLUTTER_VER"
if [ -z "${FLUTTER_VER}" ]; then
  echo "无法读取 Flutter 版本" >&2
  exit 1
fi

JAVA_MAJOR="$(java -version 2>&1 | head -1 | sed -E 's/.*version "([0-9]+).*/\1/')"
echo "==> Java major: $JAVA_MAJOR"
if [ "$JAVA_MAJOR" -ge 17 ] 2>/dev/null; then
  echo "警告: Gradle 6.7 不支持 JDK 17+，请改用 JDK 11，否则会在配置阶段失败。" >&2
fi

# The signing config in android/app/build.gradle points at this file; it is
# gitignored upstream, so create a local one on first build.
if [ ! -f android/app/qinglong.keystore ]; then
  echo "==> 生成签名密钥 android/app/qinglong.keystore"
  keytool -genkeypair -v \
    -keystore android/app/qinglong.keystore \
    -alias jiangyuesong \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass jiangyuesong -keypass jiangyuesong \
    -dname "CN=qinglong, OU=app, O=qinglong, L=cn, ST=cn, C=cn"
fi

echo "==> flutter pub get"
flutter pub get

echo "==> flutter build apk --release"
flutter build apk --release

APK="build/app/outputs/flutter-apk/app-release.apk"
if [ -f "$APK" ]; then
  echo
  echo "构建完成: $APK"
  ls -lh "$APK"
else
  echo "构建结束但没有找到 $APK" >&2
  exit 1
fi
