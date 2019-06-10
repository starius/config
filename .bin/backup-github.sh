#!/bin/sh

set -xue

user=$1
url="https://api.github.com/users/$user/repos?per_page=10000"
repos=$(curl $url|grep '"full_name"'|sed -e 's/.*: "\(.*\)",/\1/' -e "s@$user/@@")
for repo in $repos; do
    git clone "https://github.com/$user/$repo"
    git --git-dir "$repo/.git" gc --aggressive
done
TZ='Europe/London' tar --owner 0 --group 0 --numeric-owner \
    --mtime='2000-01-01 00:00' \
    -czf $user-all-github-repos.tar.gz */.git/

