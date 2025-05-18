#!/bin/bash

# save.sh - Commit and push current repo with an auto-generated commit message

# Directory of the repo
cd "$ME" || { echo "Could not cd to $ME"; exit 1; }

# Stage all changes
git add .

# If user supplied a commit message, use it instead
if [ -n "$1" ]; then
  commit_message="$*"
else
  # Generate commit message using 'hey'
  commit_message=$(git diff --staged | hey 'summarize the changes in a short git commit message. only return message, no extra fluff extra no escaping your output is used verbatim so literally return a commit message and nothing else')
fi

# Prompt user for confirmation
read -p "Commit with message: \"$commit_message\"? [Y/n] " confirm
confirm=${confirm:-Y}

if [[ "$confirm" =~ ^[Yy]$ ]]; then
  git commit -m "$commit_message"
  git push
  currentHHMM=$(date +"%H:%M")
  echo "$currentHHMM <qrx.git> $commit_message" >> "$HISTORY"
  echo "Committed and pushed!"
else
  echo "Aborted."
  exit 0
fi
