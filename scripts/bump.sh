#!/bin/bash

# @note version bump script for Saci
# @usage ./scripts/bump.sh <version> <commit-message>
# @usage ./scripts/bump.sh -v (show current version)

PROJECT_FILE="Saci.xcodeproj/project.pbxproj"

# @note get current version from project.pbxproj
get_current_version() {
    grep "MARKETING_VERSION" "$PROJECT_FILE" | head -1 | sed 's/.*= //' | sed 's/;$//'
}

# @note show current version
if [[ "$1" == "-v" || "$1" == "--version" ]]; then
    echo "Current version: $(get_current_version)"
    exit 0
fi

# @note show usage if no arguments
if [[ $# -lt 2 ]]; then
    echo "Usage: ./scripts/bump.sh <version> <commit-message>"
    echo "       ./scripts/bump.sh -v (show current version)"
    echo ""
    echo "Example: ./scripts/bump.sh 0.1.1-alpha \"feat: fix bugs\""
    exit 1
fi

NEW_VERSION="$1"
COMMIT_MESSAGE="$2"
CURRENT_VERSION=$(get_current_version)

# @note confirm version change
echo ""
echo "Version Change"
echo "─────────────────────────────────"
echo "  Current: $CURRENT_VERSION"
echo "  New:     $NEW_VERSION"
echo "─────────────────────────────────"
echo ""

while true; do
    read -p "Do you want to change the version? (Y/n): " CONFIRM_VERSION
    if [[ -z "$CONFIRM_VERSION" || "$CONFIRM_VERSION" == "y" || "$CONFIRM_VERSION" == "Y" ]]; then
        break
    elif [[ "$CONFIRM_VERSION" == "n" || "$CONFIRM_VERSION" == "N" ]]; then
        echo "Aborted."
        exit 0
    else
        echo "Invalid input. Please enter Y or n."
    fi
done

# @note update version in project.pbxproj
sed -i '' "s/MARKETING_VERSION = $CURRENT_VERSION;/MARKETING_VERSION = $NEW_VERSION;/g" "$PROJECT_FILE"

if [[ $? -ne 0 ]]; then
    echo "Error: Failed to update version in $PROJECT_FILE"
    exit 1
fi

# @note auto stage the changed file
git add "$PROJECT_FILE"

echo "✓ Version updated to $NEW_VERSION"
echo "✓ Staged $PROJECT_FILE"

# @note confirm git commit
echo ""
echo "Git Commit"
echo "─────────────────────────────────"
echo "  Message: $COMMIT_MESSAGE"
echo "─────────────────────────────────"
echo ""

while true; do
    read -p "Do you want to commit this change? (Y/n): " CONFIRM_COMMIT
    if [[ -z "$CONFIRM_COMMIT" || "$CONFIRM_COMMIT" == "y" || "$CONFIRM_COMMIT" == "Y" ]]; then
        break
    elif [[ "$CONFIRM_COMMIT" == "n" || "$CONFIRM_COMMIT" == "N" ]]; then
        echo "Version updated but not committed."
        exit 0
    else
        echo "Invalid input. Please enter Y or n."
    fi
done

# @note commit
git commit -m "$COMMIT_MESSAGE"

if [[ $? -eq 0 ]]; then
    echo "✓ Committed: $COMMIT_MESSAGE"
    echo ""
    echo "New version: $NEW_VERSION"
else
    echo "Error: Git commit failed"
    exit 1
fi
