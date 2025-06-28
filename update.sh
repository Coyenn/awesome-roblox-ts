#!/usr/bin/env bash
set -eo pipefail

echo "Updating package list in README.md..."

# Create a temporary README file
README_TMP=$(mktemp)

# Add header to the temporary README
cat > "$README_TMP" << EOF
# Awesome Roblox-TS

A list of all packages for [roblox-ts](https://roblox-ts.com/).

## Packages

EOF

# Fetch all packages and their descriptions in parallel
npm access list packages @rbxts | sed 's/:.*//' | xargs -P 16 -I {} sh -c "npm view '{}' name description --json 2>/dev/null || true" | jq -s 'map(select(type == "object" and .name)) | sort_by(.name) | .[] | "- [\(.name)](https://www.npmjs.com/package/\(.name)) - \(.description)"' | sed 's/"//g' | sed 's/<[^>]*>//g' | sed -E 's/!\[[^]]*]\([^)]*\)//g' | sed -E 's/\[]\(([^)]*)\)//g' | sed -E 's/`{3,}.*`{3,}|`{3,}.*//g' | sed 's/ - *$//' >> "$README_TMP"

# Replace the old README with the new one
mv "$README_TMP" "README.md"

echo "README.md has been updated."
