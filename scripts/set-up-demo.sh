#!/bin/sh
set -e
rokit install

: "${PROJECT:=demo.project.json}"
export PROJECT
: "${BUILD_FILE:=demo.rbxl}"
export BUILD_FILE

sh scripts/build/init.sh
rojo serve "$PROJECT"