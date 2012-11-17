# args:
# 1 local_port
# 2 host
# 3 remote_port

/usr/bin/ssh -f -N -L $1:localhost:$3 $2

