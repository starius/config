#!/bin/sh

user=$1
url="https://api.bitbucket.org/2.0/repositories/$user?pagelen=100"
repos=$(curl $url|egrep -o '"allow_forks", "name": "[^"]+"'|sed 's/.*: "\(.*\)"/\1/')
for repo in $repos; do
    echo $repo
    hg clone "https://bitbucket.org/$user/$repo"
done
TZ='Europe/London' tar --owner 0 --group 0 --numeric-owner \
    --mtime='2000-01-01 00:00' \
    -czf $user-all-bitbucket-repos.tar.gz */.hg/

