u='http://dpmaster.deathmask.net/?game=openarena&server=46.105.111.21:27960'
if wget $u -O -|grep '13vast'; then
    play -n -c3 synth sin %-12 sin %-3 sin %-5 sin %-2 fade h 0.1 3 0.1
fi

u='http://dpmaster.deathmask.net/?game=openarena&server=188.165.243.176:27960'
if wget $u -O -|grep '13vast'; then
    play -n -c3 synth sin %-12 sin %-15 sin %-5 sin %-2 fade h 0.1 1 0.1
fi

