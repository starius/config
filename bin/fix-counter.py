#!/usr/bin/python

import sys
import datetime
import time
import os
import random

cmd = sys.argv[1]
freq = int(sys.argv[2]) # base hits per day

mean = 0
day = -1
slow_hours = range(0, 10)

N = lambda mu, sigma: random.Random().normalvariate(mu, sigma)
Exp = lambda lambd: random.Random().expovariate(lambd)
now = lambda: datetime.datetime.now()

while True:
    if now().day != day:
        day = now().day
        freq_today = N(1, 0.2) * freq
        if now().isoweekday >= 6:
            freq_today /= 2.
        mean = 24*3600. / freq_today
    m = mean
    if now().hour in slow_hours:
        m *= N(0.6, 0.1)
    sleep = Exp(1./m)
    time.sleep(sleep)
    os.system(cmd)

