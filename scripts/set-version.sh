#!/bin/bash
# Update all version fields in plugin metadata files

set -e

VERSION="${1:?Usage: $0 <version>}"
DIR="$(dirname "$0")/../.claude-plugin"

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

jq --arg v "$VERSION" '.version = $v' "$DIR/plugin.json" > "$tmp" && mv "$tmp" "$DIR/plugin.json"
jq --arg v "$VERSION" '.version = $v | .plugins[0].version = $v' "$DIR/marketplace.json" > "$tmp" && mv "$tmp" "$DIR/marketplace.json"

echo "Set version to $VERSION"
