#!/bin/bash
#
# OpenSSL cross-build for iOS / iOS-simulator / macOS.
# Replaces upstream's mbedtls build.
#
# Design: use OpenSSL's `darwin64-<arch>-cc` targets uniformly (they set the
# arch-appropriate assembly + `-arch <arch>` cflag) and switch SDK / min-version
# per platform via -isysroot / -m*-version-min. This is cleaner than mixing
# ios64-cross / iossimulator-xcrun, whose CROSS_TOP/CROSS_SDK conventions and
# host-arch auto-detection differ in subtle ways.
#
# Contract with the outer Makefile (`openssl_%` rule):
#   inputs (env):  PROJECT_DIR OS ARCH SRC_DIR OUTPUT_DIR (env is scrubbed)
#   outputs:       ${OUTPUT_DIR}/{include,lib}/... (pkg-config .pc under lib/)
#
# The env is scrubbed via `env -i` in the Makefile, so we don't inherit
# MAKEFLAGS, CFLAGS, etc. — that means we can safely pass everything through
# ./Configure without worrying about outer overrides polluting the openssl
# build.

set -eu

cd "${SRC_DIR}"

IOS_MIN=9.0
MAC_MIN=10.13

case "${OS}-${ARCH}" in
    macos-amd64)
        TARGET=darwin64-x86_64-cc
        SDK_NAME=macosx
        MIN_FLAG=-mmacosx-version-min=${MAC_MIN}
        ;;
    macos-arm64)
        TARGET=darwin64-arm64-cc
        SDK_NAME=macosx
        MIN_FLAG=-mmacosx-version-min=${MAC_MIN}
        ;;
    ios-arm64)
        TARGET=darwin64-arm64-cc
        SDK_NAME=iphoneos
        MIN_FLAG=-miphoneos-version-min=${IOS_MIN}
        ;;
    iossimulator-amd64)
        TARGET=darwin64-x86_64-cc
        SDK_NAME=iphonesimulator
        MIN_FLAG=-mios-simulator-version-min=${IOS_MIN}
        ;;
    iossimulator-arm64)
        TARGET=darwin64-arm64-cc
        SDK_NAME=iphonesimulator
        MIN_FLAG=-mios-simulator-version-min=${IOS_MIN}
        ;;
    *)
        echo "openssl/build.sh: unsupported OS-ARCH: ${OS}-${ARCH}" >&2
        exit 1
        ;;
esac

SYSROOT=$(xcrun --sdk "${SDK_NAME}" --show-sdk-path)

# Options rationale:
#   shared          : build .dylibs (relink-dylibs.sh + framework build both
#                     operate on dylibs). OpenSSL 3.x has no "no-static"
#                     option — .a's are always built alongside .dylib's;
#                     the downstream find in libs-arch/build.sh filters
#                     to *.dylib so the .a's are harmless.
#   no-tests no-apps: skip test suite + `openssl` CLI (halves build time,
#                     no runtime effect on ffmpeg's libssl/libcrypto usage)
#   no-docs         : skip pod2man
#   no-engine       : drop engines-3/{padlock,capi,loader_attic}.dylib. These
#   no-legacy         and ossl-modules/legacy.dylib are dlopen-able MODULES,
#                     not link targets: despite the .dylib extension their
#                     Mach-O type is MH_BUNDLE, so the framework packaging
#                     step downstream would turn them into xcframeworks that
#                     fail every link ("building for macOS, but linking in
#                     object file built for ..."/bundle-not-linkable).
#                     Dropping them is behaviour-neutral here: OpenSSL only
#                     dlopens modules from its compile-time configured path,
#                     which no longer exists once we relocate into framework
#                     bundles — they could never load either way. And nothing
#                     in this stack wants them: legacy carries MD2/MD4/DES/
#                     RC2/RC4/Blowfish/IDEA/SEED, none of which appear in TLS
#                     1.2/1.3 suites; --enable-protocol=crypto uses FFmpeg's
#                     own libavutil/aes.c; rtmpe (the RC4 user) is not built.
#                     The three engines are VIA-CPU / Windows-CryptoAPI /
#                     legacy-store shims, meaningless on Apple platforms, and
#                     the ENGINE API is deprecated in OpenSSL 3 anyway.
#   --libdir=lib    : some hosts default to lib64; force lib for stable
#                     pkg-config paths downstream
./Configure "${TARGET}" \
    shared no-tests no-apps no-docs no-engine no-legacy \
    --prefix="${OUTPUT_DIR}" \
    --libdir=lib \
    -isysroot "${SYSROOT}" \
    "${MIN_FLAG}"

# SANDBOX_PATH only has /bin:/usr/bin — `sysctl` lives in /usr/sbin. Use
# getconf (in /usr/bin) with a conservative fallback.
CORES=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)
make -j"${CORES}" build_sw
make install_sw
