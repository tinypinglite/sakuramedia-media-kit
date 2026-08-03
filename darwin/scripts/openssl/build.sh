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
#   shared no-static  : we ship .dylibs (relink-dylibs.sh + framework build
#                       both operate on dylibs)
#   no-tests no-apps  : skip test suite + `openssl` CLI (halves build time,
#                       no runtime effect on ffmpeg's libssl/libcrypto usage)
#   no-docs           : skip pod2man
#   --libdir=lib      : some hosts default to lib64; force lib for stable
#                       pkg-config paths downstream
./Configure "${TARGET}" \
    shared no-static no-tests no-apps no-docs \
    --prefix="${OUTPUT_DIR}" \
    --libdir=lib \
    -isysroot "${SYSROOT}" \
    "${MIN_FLAG}"

CORES=$(sysctl -n hw.ncpu)
make -j"${CORES}" build_sw
make install_sw
