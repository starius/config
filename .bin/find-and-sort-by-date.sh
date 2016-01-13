#!/bin/sh

# source: http://superuser.com/a/294164

find -type f -printf '%T@ %p\n' | sort -k 1nr | sed 's/^[^ ]* //'
