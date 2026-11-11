#!/usr/bin/env bash
set -euo pipefail
command -v cargo-ndk >/dev/null || cargo install cargo-ndk
rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android
: "${ANDROID_NDK_HOME:?Set ANDROID_NDK_HOME}"
cargo ndk -t arm64-v8a -t armeabi-v7a -t x86_64 \
  -o flutter_app/android/app/src/main/jniLibs build --release
