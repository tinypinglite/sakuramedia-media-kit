#!/bin/sh

set -e # exit immediately if a command exits with a non-zero status
set -u # treat unset variables as an error

mkdir -p ${OUTPUT_DIR}/bin

# check BINARY presence in PATH — fail loudly if a required tool is
# missing (upstream silently swallowed this with `|| true`; a missing
# binary then surfaced hundreds of lines later as an opaque "Unable to
# find X" from a downstream meson build).
for BINARY in ${BINARIES}; do
    if ! command -v "$BINARY" >/dev/null 2>&1; then
        echo "links: FATAL — $BINARY not found in PATH: $PATH" >&2
        exit 1
    fi
done

# sym link BINARY
for BINARY in ${BINARIES}; do
    if [ ! -h "${OUTPUT_DIR}/bin/$BINARY" ]; then
        ln -s "$(command -v "$BINARY")" "${OUTPUT_DIR}/bin/$BINARY"
    fi
done
echo "links: symlinked: $(ls ${OUTPUT_DIR}/bin | tr '\n' ' ')"
