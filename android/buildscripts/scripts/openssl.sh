#!/bin/bash -e

. ../../include/depinfo.sh
. ../../include/path.sh

if [ "$1" == "build" ]; then
	true
elif [ "$1" == "clean" ]; then
	make distclean >/dev/null 2>&1 || true
	exit 0
else
	exit 255
fi

# In-tree build; build.sh loops over all ABIs in the same source dir,
# so always reconfigure from a clean tree (same approach as mbedtls.sh had).
make distclean >/dev/null 2>&1 || true

# OpenSSL's android-* Configure targets need ANDROID_NDK_ROOT and the NDK
# toolchain on PATH (path.sh already adds it), and pick their own clang;
# the CC/CXX/AS exported by build.sh must not leak in.
export ANDROID_NDK_ROOT="$DIR/sdk/android-sdk-linux/ndk/$v_ndk"

target=android-arm
[[ "$ndk_triple" == "aarch64"* ]] && target=android-arm64
[[ "$ndk_triple" == "i686"* ]] && target=android-x86
[[ "$ndk_triple" == "x86_64"* ]] && target=android-x86_64

env -u CC -u CXX -u AS -u AR -u RANLIB -u LDFLAGS \
	perl ./Configure $target -D__ANDROID_API__=21 -fPIC \
	--prefix=/usr/local --libdir=lib \
	no-shared no-tests

env -u CC -u CXX -u AS -u AR -u RANLIB -u LDFLAGS \
	make -j$cores build_sw

env -u CC -u CXX -u AS -u AR -u RANLIB -u LDFLAGS \
	make DESTDIR="$prefix_dir" install_sw
