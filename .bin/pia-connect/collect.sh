#!/bin/bash

# Run pia-connect in dry mode again and again to collect a lot of servers.

# Public DNS servers used below are:
# 8.8.8.8 https://developers.google.com/speed/public-dns/
# 77.88.8.8 https://dns.yandex.ru
# 80.80.80.80 http://freenom.world

while sleep 1; do
    UPSTREAM="$(shuf -e 8.8.8.8 77.88.8.8 80.80.80.80 | head -1 | awk '{$1=$1};1'):53"
    timeout 50 \
        pia-connect \
        -dry \
        -dns-listen 0.0.0.0:1153 \
        -dns-upstream "$UPSTREAM" \
        -update-wait 0s \
        -update-all-zones
done
