# sakuramedia-media-kit

为 [sakuramedia](https://github.com/tinypinglite/sakuramedia) 维护的 media-kit 原生库自建版本：
把上游 libmpv 构建中 FFmpeg 的 **mbedTLS 换成 OpenSSL**，用 GitHub Actions 构建，
产物发布到本仓库 Release，sakuramedia 通过 `dependency_overrides` 直接消费。

锁定的上游版本（与 sakuramedia 的 pubspec.lock 对齐）：

| 包 | 版本 | 对应二进制来源 |
| --- | --- | --- |
| media_kit | 1.2.6 | — |
| media_kit_video | 1.3.1 | — |
| media_kit_libs_video | 1.0.7 | — |
| media_kit_libs_android_video | 1.3.8 | libmpv-android-video-build **v1.1.7** |
| media_kit_libs_ios_video | 1.1.4 | libmpv-darwin-build **v0.6.0**（video-default） |
| media_kit_libs_macos_video | 1.1.4 | libmpv-darwin-build **v0.6.0**（video-default） |
| media_kit_libs_windows_video | 1.0.11 | libmpv-win32-video-build 2023-09-24（未做） |

## 目录结构

```
android/                 libmpv-android-video-build v1.1.7 的 vendor + OpenSSL 改造
  buildscripts/            include/depinfo.sh + download-deps.sh + scripts/openssl.sh
                           + flavors/*.sh 把 mbedtls 3.4.0 换成 openssl 3.5.7
darwin/                  libmpv-darwin-build v0.6.0 的 vendor + OpenSSL 改造
  Makefile               mbedtls_* → openssl_*
  downloads.lock         mbedtls 3.4.1 → openssl 3.5.7 (Apache-2.0)
  scripts/openssl/       新增：直接跑 OpenSSL 的 Perl Configure，per-arch iOS/macOS 交叉编译
  scripts/ffmpeg/        --enable-mbedtls → --enable-openssl
.github/workflows/
  build-android.yml      推 android-v* → 4 个 ABI JAR → Release
  build-darwin.yml       推 darwin-v* → iOS + macOS universal xcframework tarballs → Release
                         （只构建 video-default，跳过 audio/full/encodersgpl，保持 <90min）
packages/                四个 media_kit_libs_*_video 的薄 fork
  media_kit_libs_android_video/   build.gradle 指向本仓库 Release
  media_kit_libs_ios_video/       ios/Makefile 指向本仓库 Release
  media_kit_libs_macos_video/     macos/Makefile 指向本仓库 Release
tools/
  update-android-hashes.sh        发完 android-v* Release 刷 build.gradle 里的 tag+MD5
  update-darwin-hashes.sh         发完 darwin-v* Release 刷两个 Makefile 里的 tag+SHA256
```

## 发版流程

### Android

```bash
git tag android-v1.1.7-openssl.1 && git push origin android-v1.1.7-openssl.1
# 等 Actions 完成 → Release 发布（约 20 分钟）
tools/update-android-hashes.sh android-v1.1.7-openssl.1
git commit -am "android: point libs package at android-v1.1.7-openssl.1"
git push
```

### Darwin (iOS + macOS)

```bash
git tag darwin-v0.6.0-openssl.1 && git push origin darwin-v0.6.0-openssl.1
# 等 macos-13 runner 跑完（预计 60-90 分钟：5 arch × 10 deps）
tools/update-darwin-hashes.sh darwin-v0.6.0-openssl.1
git commit -am "darwin: point libs packages at darwin-v0.6.0-openssl.1"
git push
```

## sakuramedia 侧消费

```yaml
dependency_overrides:
  media_kit_libs_android_video:
    git: {url: https://github.com/tinypinglite/sakuramedia-media-kit.git,
          path: packages/media_kit_libs_android_video, ref: main}
  media_kit_libs_ios_video:
    git: {url: https://github.com/tinypinglite/sakuramedia-media-kit.git,
          path: packages/media_kit_libs_ios_video, ref: main}
  media_kit_libs_macos_video:
    git: {url: https://github.com/tinypinglite/sakuramedia-media-kit.git,
          path: packages/media_kit_libs_macos_video, ref: main}
```

之后 `flutter build apk|ios|macos` 会自动从本仓库 Release 下载并校验校验和。

## 许可证说明

FFmpeg 以 `--disable-gpl --enable-version3`（LGPLv3）构建；OpenSSL 3.x 为 Apache-2.0，
与 LGPLv3 兼容。FFmpeg 6.0 的 configure 对 OpenSSL≥3 仅在 GPL 模式下有额外要求，本配置
不受影响，无需 `--enable-nonfree`。

## TLS 行为说明

FFmpeg 的 `tls_verify=0` 默认不校验证书，mpv 的 `--tls-verify` 默认也是关闭——换成
OpenSSL 后此行为不变。

## 待办

- Windows：fork [libmpv-win32-video-build](https://github.com/media-kit/libmpv-win32-video-build)
  （已 archive），其 `packages/openssl.cmake` 现成，把 `ffmpeg.cmake` 的
  `DEPENDS mbedtls` / `--enable-mbedtls` 换成 openssl 即可。
