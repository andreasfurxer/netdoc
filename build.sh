#!/bin/sh
# Optional: Image lokal bauen (zum Testen). Im Normalfall baut GitHub Actions das Image.
set -e
cd "$(dirname "$0")"
VERSION=$(sed -n "s/.*APP_VERSION = '\([^']*\)'.*/\1/p" src/index.php | head -1)
[ -n "$VERSION" ] || { echo "Version nicht gefunden"; exit 1; }
docker build -t "netdoc:${VERSION}" .
echo "Fertig: netdoc:${VERSION} (lokal)"
