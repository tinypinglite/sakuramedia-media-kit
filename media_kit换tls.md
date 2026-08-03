先摸清 4 个 lib 包的**当前交付形态**——vendor 方案要"就地替换"就必须对齐上游接口。

明白。四个平台的交付格式我摸清楚了，方案就一个 shape。

## 全平台交付格式（已核实）

| 平台    | 交付形态                                                     | 上游包大小         | 二进制体积                             |
| ------- | ------------------------------------------------------------ | ------------------ | -------------------------------------- |
| Android | Gradle 从 GH Release 下载 4 个 JAR（含 `libmpv.so`）         | 40KB（不含二进制） | ~48MB（4 ABI × 12MB）                  |
| iOS     | podspec `make` 从 GH Release 下 tarball，展开 ~19 个 `.xcframework` | 36KB（不含二进制） | ~60-80MB（含 device+simulator slices） |
| macOS   | **`.xcframework` 直接在包里** ← 已经 vendor 了！             | **59MB**           | ~60MB                                  |
| Windows | CMake `ExternalProject_Add` 从 GH Release 下 `.7z`           | 36KB（不含二进制） | ~30-40MB DLL                           |

**关键发现**：**macOS 上游已经是 vendor 模式**，把 xcframework 打进了 pub 包本身（59MB）。这就是我们要给其他三个平台复制的形态。

## 方案

### 目录结构

```
sakuramedia/
├── packages/                                              ← 新增
│   ├── media_kit_libs_android_video/
│   │   ├── android/
│   │   │   ├── build.gradle.kts          ← 改：删下载,改从 jniLibs 拿
│   │   │   └── src/main/jniLibs/         ← 新:直接放 .so
│   │   │       ├── arm64-v8a/libmpv.so   ← 提交进 git
│   │   │       ├── armeabi-v7a/libmpv.so
│   │   │       ├── x86/libmpv.so
│   │   │       └── x86_64/libmpv.so
│   │   └── pubspec.yaml                  ← 从 pub-cache 抄
│   ├── media_kit_libs_ios_video/
│   │   ├── ios/
│   │   │   ├── media_kit_libs_ios_video.podspec  ← 去掉 system("make")
│   │   │   ├── Makefile                          ← 保留(no-op)或直接删
│   │   │   └── Frameworks/*.xcframework          ← 直接提交
│   │   └── pubspec.yaml
│   ├── media_kit_libs_macos_video/       ← 抄 pub-cache 原样即可(已 vendor)
│   │   ├── macos/
│   │   │   ├── media_kit_libs_macos_video.podspec
│   │   │   └── Frameworks/*.xcframework          ← 替换成 openssl 版
│   │   └── pubspec.yaml
│   └── media_kit_libs_windows_video/
│       ├── windows/
│       │   ├── CMakeLists.txt            ← 改:从 vendored/ 拷贝,不下载
│       │   └── vendored/                 ← 新
│       │       ├── libmpv-2.dll          ← 提交
│       │       ├── include/mpv/*.h
│       │       └── *.lib(import lib)
│       └── pubspec.yaml
│
├── pubspec.yaml                          ← 加 dependency_overrides
│
└── tools/build-media-kit-libs/           ← 新:三个 fork 的构建脚本
    ├── README.md                          ← 如何重编、如何滚版本
    ├── build-android.sh                   ← 用你 fork 的 libmpv-android-video-build
    ├── build-darwin.sh                    ← 用你 fork 的 libmpv-darwin-build
    ├── build-windows.sh                   ← 用你 fork 的 libmpv-win32-video-build
    └── vendor-binaries.sh                 ← 把 3 处 build 产物拷到 packages/*
```

### `pubspec.yaml` 一次改动，全平台生效

```yaml
dependency_overrides:
  media_kit_libs_android_video:
    path: ./packages/media_kit_libs_android_video
  media_kit_libs_ios_video:
    path: ./packages/media_kit_libs_ios_video
  media_kit_libs_macos_video:
    path: ./packages/media_kit_libs_macos_video
  media_kit_libs_windows_video:
    path: ./packages/media_kit_libs_windows_video
```

之后 `flutter run` / `flutter build apk|ipa|macos|windows` 全部自动用本地 vendor 的二进制，**CI 不需要任何特殊配置**——因为二进制已经在 git 里了，`git clone` 就有。

### 二进制怎么来（一次性 + 后续更新）

三个上游 fork，各一次构建：

| 平台      | Fork                                                         | 构建位置                                                     | 时长                   | 产物                                          |
| --------- | ------------------------------------------------------------ | ------------------------------------------------------------ | ---------------------- | --------------------------------------------- |
| Android   | [libmpv-android-video-build](https://github.com/media-kit/libmpv-android-video-build) | GH Actions（已有 workflow）                                  | ~30min                 | 4 个 JAR → 解开取 `.so`                       |
| iOS+macOS | [libmpv-darwin-build](https://github.com/media-kit/libmpv-darwin-build) | **你 Mac 本地** 跑 Nix（这个 repo 是 Nix 驱动的，没有 GH Actions） | ~60min 首次 / 后续增量 | iOS + macOS 两套 xcframework tarball          |
| Windows   | [libmpv-win32-video-build](https://github.com/media-kit/libmpv-win32-video-build) | GH Actions（已有 workflow）或 Docker on Linux                | ~40min                 | `mpv-dev-x86_64-*.7z` → 解开取 `libmpv-2.dll` |

**每个 fork 只改 2-4 处**（`--enable-mbedtls` → `--enable-openssl --enable-nonfree`，加个 openssl 依赖）。我已经给你 Android 的完整 patch，Windows 和 Darwin 的 patch 我可以照样出。

`tools/build-media-kit-libs/vendor-binaries.sh` 是把这三处产物**自动拷贝**到 `packages/*/` 对应位置的脚本，一条命令搞定 vendor。

## 仓库体积影响（提前告知）

**新增体积**：~200MB（macOS 已经有 59MB 了，是净新增 ~140MB）

- Android .so × 4: 48MB
- iOS xcframeworks: 60MB
- macOS xcframeworks: 60MB（替换旧的，净增量约 0）
- Windows dll + headers: 30MB

**git clone 时间**：+3-5s 在 100Mbps 网上；国内小水管可能 +30s-1min。

**长期滚版本**的顾虑：每次重编把二进制换掉，git 会把新旧两份都存进 history。三次滚 mpv 版本 ≈ 600MB history。

**两种缓解**（推荐第二种）：

1. **直接提交**（你说的方案）——简单，缺点是 history 会涨
2. **用 Git LFS 管 `packages/\**/\*.{so,xcframework,dll,a}`** —— 二进制存 LFS，git repo 保持小；`git clone` 时自动拉。GH 免费额度 1GB 存储 + 1GB/月带宽，够你个人项目用；如果超了，切到私有 LFS provider 也行。**接入成本就一个 `.gitattributes` 文件**。

我倾向**用 LFS**——现在多一次配置，将来滚版本无痛。

## 需要你确认

1. **LFS 还是直接提交**？我倾向 LFS，理由如上。你决定。

2. **Android 是否只保留 `arm64-v8a`**？现代手机全 arm64，去掉另外 3 个 ABI 能省 36MB（约总量的 15-20%）。sakuramedia 应该没有 armv7 用户吧？

3. **iOS simulator slice 要不要**？xcframework 里默认含 device (arm64) + simulator (arm64+x86_64) 两片。开发时需要 simulator 片才能跑，发布 App Store 不用。**开发要**，所以保留吧。

4. **Windows 有真实用户吗**？没有就先不做 Windows 那份 fork，省一堆事。有的话我再出 patch。

5. 谁负责第一次编译

   ？三个 fork 的构建：

   - Android + Windows：push 到 fork 触发 GH Actions，你等 CI，下 artifact
   - Darwin：你 Mac 上 Nix 本地跑（我可以写 Makefile 帮你自动化）

想清楚这几个我就动手：先把 `packages/` 的 4 个 fork 骨架搭好（无二进制），再一个平台一个平台地引入二进制。这样每一步都能独立验证，不会一次改一大堆。要不要我先动手把 packages/ 骨架搭好，同时把 Darwin 和 Windows 两份 fork 的 patch 也写出来？