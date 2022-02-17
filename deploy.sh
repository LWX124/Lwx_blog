#!/bin/bash
# Program:
#   发布Hugo生成文件到GitHub Pages
# History:
# If a command fails then the deploy stops
set -e


branch='main'

printf "\033[0;32mDeploying updates to GitHub...\033[0m\n"

# Build the project.
hugo --minify # if using a theme, replace with `Hugo -t <YOURTHEME>`

# Go To Public folder
cd publish/github

# Add changes to git.
git add .

# Commit changes.
msg="Published on $(date +'%Y-%m-%d %H:%M:%S')"
if [ -n "$*" ]; then
    msg="$*"
fi
git commit -m "$msg"

git pull --rebase origin $branch
# Push source and build repos.
git push -f origin $branch