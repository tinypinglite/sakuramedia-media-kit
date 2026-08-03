#!/bin/bash -e

# --------------------------------------------------

. ./include/depinfo.sh

rm -rf deps prefix

./download.sh
./patch.sh

# --------------------------------------------------

rm -f scripts/ffmpeg.sh
cp flavors/default.sh scripts/ffmpeg.sh

# --------------------------------------------------

./build.sh

zip -r debug-symbols-default.zip prefix/*/lib

# Strip with the same NDK declared in depinfo.sh (upstream hardcoded an
# unrelated preinstalled NDK path here).
STRIP=$(echo ./sdk/android-sdk-linux/ndk/$v_ndk/toolchains/llvm/prebuilt/*/bin/llvm-strip)
for abi in arm64-v8a armeabi-v7a x86 x86_64; do
	"$STRIP" --strip-all prefix/$abi/usr/local/lib/libmpv.so
done

# --------------------------------------------------

cd deps/media-kit-android-helper

chmod +x gradlew
./gradlew assembleRelease

unzip -o app/build/outputs/apk/release/app-release.apk -d app/build/outputs/apk/release

cp ../../prefix/arm64-v8a/usr/local/lib/libmpv.so      app/build/outputs/apk/release/lib/arm64-v8a
cp ../../prefix/armeabi-v7a/usr/local/lib/libmpv.so    app/build/outputs/apk/release/lib/armeabi-v7a
cp ../../prefix/x86/usr/local/lib/libmpv.so            app/build/outputs/apk/release/lib/x86
cp ../../prefix/x86_64/usr/local/lib/libmpv.so         app/build/outputs/apk/release/lib/x86_64

cd app/build/outputs/apk/release

zip -r default-arm64-v8a.jar      lib/arm64-v8a/*.so
zip -r default-armeabi-v7a.jar    lib/armeabi-v7a/*.so
zip -r default-x86.jar            lib/x86/*.so
zip -r default-x86_64.jar         lib/x86_64/*.so

md5sum *.jar
