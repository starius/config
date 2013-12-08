#!/usr/bin/python

import sys
import datetime

prev = 0

for line in sys.stdin:
    if not line.startswith('['):
        continue
    t = int(float((line.split(']')[0][1:])))
    if prev != 0 and t - prev > 5:
        d = datetime.datetime.fromtimestamp(prev)
        d2 = datetime.datetime.fromtimestamp(t)
        print(d.strftime('%Y-%m-%d %H:%M:%S') + ' - ' +
                d2.strftime('%Y-%m-%d %H:%M:%S'))
    prev = t
