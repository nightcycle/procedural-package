#!/bin/sh
set -e
echo "Building project..."
wally install
: "${SOURCEMAP:=sourcemap.json}"
# : "${PROJECT:=dev.project.json}"
export PROJECT="demo.project.json"
rojo sourcemap "$PROJECT" --output "$SOURCEMAP"
set +e
: "${WALLY_PACKAGE_DIR:=Packages}"
wally-package-types "$WALLY_PACKAGE_DIR" --sourcemap "$SOURCEMAP"
if [ -d "DevPackages" ]; then
	wally-package-types "DevPackages" --sourcemap "$SOURCEMAP"
fi
set -e
