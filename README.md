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
| media_kit_libs_ios_video / macos_video | 1.1.4 | libmpv-darwin-build v0.6.0（未做） |
| media_kit_libs_windows_video | 1.0.11 | libmpv-win32-video-build 2023-09-24（未做） |

## 目录结构

```
android/                 libmpv-android-video-build v1.1.7 的 vendor + OpenSSL 改造
  buildscripts/            改动点：
                             include/depinfo.sh        mbedtls 3.4.0 → openssl 3.5.7
                             include/download-deps.sh  克隆 openssl 源码
                             scripts/openssl.sh        新增（NDK 交叉编译，静态库）
                             flavors/*.sh              --enable-mbedtls → --enable-openssl
                             bundle_default.sh         加 shebang/-e、strip 改用 depinfo 的 NDK
.github/workflows/
  build-android.yml      推 android-v* 标签 → 构建 → 发 Release（4 个 JAR + 调试符号 + md5）
packages/
  media_kit_libs_android_video/   pub 上 1.3.8 的薄 fork，只改 build.gradle 的下载源
tools/
  update-android-hashes.sh        发完 Release 后刷新 build.gradle 里的 tag 和 MD5
```

## 发版流程（Android）

```bash
# 1. 打标签触发构建（也可以先 workflow_dispatch 手动跑一次验证）
git tag android-v1.1.7-openssl.1 && git push origin android-v1.1.7-openssl.1

# 2. 等 Actions 完成、Release 发布后，刷新 libs 包里的 hash 并提交
tools/update-android-hashes.sh android-v1.1.7-openssl.1
git commit -am "android: point libs package at android-v1.1.7-openssl.1"
git push
```

sakuramedia 侧（已配置）：

```yaml
dependency_overrides:
  media_kit_libs_android_video:
    git:
      url: https://github.com/tinypinglite/sakuramedia-media-kit.git
      path: packages/media_kit_libs_android_video
      ref: main
```

之后 `flutter build apk` 会在 Gradle 阶段自动从本仓库 Release 下载 JAR 并校验 MD5。

## 许可证说明

FFmpeg 以 `--disable-gpl --enable-version3`（LGPLv3）构建；OpenSSL 3.x 为 Apache-2.0，
与 LGPLv3 兼容，FFmpeg 6.0 的 configure 对 OpenSSL≥3 仅在 GPL 模式下有额外要求，
本配置不受影响，无需 `--enable-nonfree`。

## TLS 行为说明

FFmpeg 的 https 默认 `tls_verify=0`（不校验证书），mpv 的 `--tls-verify` 默认也是关闭，
上游 mbedTLS 版本同样如此——换成 OpenSSL 后此行为不变，不存在"Android 上找不到系统
CA store"的问题。

## 待办（其他平台）

- iOS/macOS：fork [libmpv-darwin-build](https://github.com/media-kit/libmpv-darwin-build)
  v0.6.0（Nix + meson，上游本来就在 GH Actions 的 macOS runner 上构建），给 OpenSSL 加
  ios/ios-simulator/macos 各架构的交叉编译配方。
- Windows：fork [libmpv-win32-video-build](https://github.com/media-kit/libmpv-win32-video-build)
  （已 archive），其 `packages/openssl.cmake` 现成，把 `ffmpeg.cmake` 的
  `DEPENDS mbedtls` / `--enable-mbedtls` 换成 openssl 即可。
