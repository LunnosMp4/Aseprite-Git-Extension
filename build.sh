#!/bin/bash

EXT_NAME="aseprite-git-extension"
OUT_FILE="$EXT_NAME.aseprite-extension"

rm -f "$OUT_FILE"

cd "$EXT_NAME" || exit
zip -r "../$OUT_FILE" ./*
cd ..

echo "✅ Built $OUT_FILE"
