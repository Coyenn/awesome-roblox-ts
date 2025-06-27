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

# Fetch all packages using npm search and format them
npm search @rbxts --json --searchlimit 9999 | jq -r '.[] | "- [`\(.name)`](https://www.npmjs.com/package/\(.name | @uri)) - \(.description // "" | gsub("[\\r\\n]+"; " "))"' | sed 's/<[^>]*>//g' | sed -E 's/!\[[^]]*]\([^)]*\)//g' | sed -E 's/\[]\(([^)]*)\)//g' | sed -E 's/`{3,}.*`{3,}|`{3,}.*//g' | sed 's/ - *$//' | sort >> "$README_TMP"

# Replace the old README with the new one
mv "$README_TMP" "README.md"

echo "README.md has been updated."
