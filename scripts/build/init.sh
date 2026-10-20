#!/bin/sh
set -e
echo "Building project..."

: "${PROJECT:=default.project.json}"
echo "Using project file: $PROJECT"
export PROJECT

: "${SOURCEMAP:=sourcemap.json}"
echo "Using sourcemap path: $SOURCEMAP"
export SOURCEMAP

: "${BUILD_FILE:=build.rbxl}"
echo "Using project file: $BUILD_FILE"
export BUILD_FILE

if [ "$PROJECT" = "dev.project.json" ]; then
	: "${DEV_WALLY_PACKAGE_DIR:=DevPackages}"
	echo "Using Wally package directory: $DEV_WALLY_PACKAGE_DIR"
	export DEV_WALLY_PACKAGE_DIR

	if [ ! -d "$DEV_WALLY_PACKAGE_DIR" ]; then
		mkdir -p "$DEV_WALLY_PACKAGE_DIR"
	fi

	if [ ! -d "dev/shared" ]; then
		mkdir -p "dev/shared"
	fi
fi

: "${WALLY_PACKAGE_DIR:=Packages}"

rojo sourcemap "$PROJECT" --output "$SOURCEMAP"

sh scripts/build/wally-install.sh

echo "Build complete."

echo "project: '$PROJECT'"
if [ "$PROJECT" = "dev.project.json" ]; then
	sh scripts/build/wally-install.sh
fi

# asphalt sync --target studio
rojo sourcemap "$PROJECT" --output "$SOURCEMAP"

rojo build "$PROJECT" --output "$BUILD_FILE"