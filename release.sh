#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: ./release.sh v1.2.3"
  exit 1
fi

TAG=$1
VERSION=${TAG#v}  # Strip the 'v' prefix for package.json

EXT_DIR="aseprite-git-extension"
EXT_JSON="$EXT_DIR/package.json"

echo "🔧 Updating version in $EXT_JSON to $VERSION..."
sed -i '' "s/\"version\": \".*\"/\"version\": \"$VERSION\"/" "$EXT_JSON"

git add "$EXT_JSON"
git commit -m "Release $TAG"
git tag "$TAG"
git push
git push origin "$TAG"

echo "🚀 Tagged and pushed $TAG."
