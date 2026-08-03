#!/bin/bash -e
# Refresh the release tag + MD5 checksums in the Android libs package after a
# new "android-v*" GitHub Release has been published by CI.
#
# Usage: tools/update-android-hashes.sh <release-tag>
#   e.g. tools/update-android-hashes.sh android-v1.1.7-openssl.1

TAG=${1:?usage: tools/update-android-hashes.sh <release-tag>}
REPO=tinypinglite/sakuramedia-media-kit

cd "$(dirname "$0")/.."
GRADLE=packages/media_kit_libs_android_video/android/build.gradle

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

for abi in arm64-v8a armeabi-v7a x86_64 x86; do
	url="https://github.com/$REPO/releases/download/$TAG/default-$abi.jar"
	echo "Downloading $url"
	curl -fL --retry 3 "$url" -o "$tmp/default-$abi.jar"
	if command -v md5sum >/dev/null; then
		md5=$(md5sum "$tmp/default-$abi.jar" | awk '{print $1}')
	else
		md5=$(md5 -q "$tmp/default-$abi.jar")
	fi
	echo "$abi: $md5"
	# Rewrite the md5 only on the line that references this ABI's jar.
	python3 - "$GRADLE" "$abi" "$md5" <<'EOF'
import re, sys
path, abi, md5 = sys.argv[1:]
lines = open(path).read().splitlines(keepends=True)
hits = 0
for i, line in enumerate(lines):
    if f"default-{abi}.jar" in line and '"md5"' in line:
        lines[i] = re.sub(r'"md5": "[^"]*"', f'"md5": "{md5}"', line)
        hits += 1
assert hits == 1, f"expected exactly 1 md5 line for {abi}, found {hits}"
open(path, "w").writelines(lines)
EOF
done

# Point releaseTag at the new release.
python3 - "$GRADLE" "$TAG" <<'EOF'
import re, sys
path, tag = sys.argv[1:]
s = open(path).read()
s, n = re.subn(r'def releaseTag = "[^"]*"', f'def releaseTag = "{tag}"', s)
assert n == 1, "expected exactly 1 releaseTag line"
open(path, "w").write(s)
EOF

echo
echo "Done. $GRADLE now points at $TAG:"
grep -E 'releaseTag = |"md5"' "$GRADLE"
