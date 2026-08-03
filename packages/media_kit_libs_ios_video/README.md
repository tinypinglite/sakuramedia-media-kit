# [package:media_kit_libs_ios_video](https://github.com/media-kit/media-kit)

> **Fork notice**: this is a fork of upstream `media_kit_libs_ios_video` 1.1.4
> maintained in [sakuramedia-media-kit](https://github.com/tinypinglite/sakuramedia-media-kit).
> The only change is in `ios/Makefile`: the xcframework tarball is downloaded
> from this project's own GitHub Releases, which rebuild libmpv with **OpenSSL**
> instead of upstream's mbedTLS. Consume via `dependency_overrides`.

[![](https://img.shields.io/discord/1079685977523617792?color=33cd57&label=Discord&logo=discord&logoColor=discord)](https://discord.gg/h7qf2R9n57) [![Github Actions](https://github.com/media-kit/media-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/media-kit/media-kit/actions/workflows/ci.yml)

iOS package providing video (& audio) native libraries for [`package:media_kit`](https://github.com/media-kit/media-kit).

Visit [media-kit/libmpv-darwin-build@`main`](https://github.com/media-kit/libmpv-darwin-build/tree/main) for descriptive details.

Thanks to [Julien Muret](https://github.com/birros) for libmpv & FFmpeg builds for iOS.

## License

Copyright © 2022, Hitesh Kumar Saini <<saini123hitesh@gmail.com>>

This project & the work under this repository is governed by MIT license that can be found in the [LICENSE](./LICENSE) file.
