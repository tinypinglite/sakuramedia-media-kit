#!/bin/bash -e
# Refresh the release tag + SHA256 checksums in the iOS/macOS libs packages
# after a new "darwin-v*" GitHub Release has been published by CI.
#
# Usage: tools/update-darwin-hashes.sh <release-tag>
#   e.g. tools/update-darwin-hashes.sh darwin-v0.6.0-openssl.1

TAG=${1:?usage: tools/update-darwin-hashes.sh <release-tag>}
REPO=tinypinglite/sakuramedia-media-kit

cd "$(dirname "$0")/.."

for platform in ios macos; do
	pkg=packages/media_kit_libs_${platform}_video/${platform}/Makefile
	url="https://github.com/$REPO/releases/download/$TAG/libmpv-xcframeworks_${TAG}_${platform}-universal-video-default.tar.gz"
	echo "Downloading $url"
	tmp=$(mktemp)
	curl -fL --retry 3 "$url" -o "$tmp"
	sha=$(shasum -a 256 "$tmp" | awk '{print $1}')
	rm -f "$tmp"
	echo "${platform}: $sha"
	python3 - "$pkg" "$TAG" "$sha" <<'EOF'
import re, sys
path, tag, sha = sys.argv[1:]
s = open(path).read()
s, n1 = re.subn(r'MPV_XCFRAMEWORKS_VERSION=\S+', f'MPV_XCFRAMEWORKS_VERSION={tag}', s)
assert n1 == 1, f'expected 1 VERSION line, got {n1}'
s, n2 = re.subn(r'MPV_XCFRAMEWORKS_SHA256SUM=\S+', f'MPV_XCFRAMEWORKS_SHA256SUM={sha}', s)
assert n2 == 1, f'expected 1 SHA256SUM line, got {n2}'
open(path, 'w').write(s)
EOF
done

echo
echo "Done. Both Makefiles now point at $TAG:"
grep -E 'MPV_XCFRAMEWORKS_(VERSION|SHA256SUM)=' \
	packages/media_kit_libs_ios_video/ios/Makefile \
	packages/media_kit_libs_macos_video/macos/Makefile
