# args:
# 1 local_port
# 2 host
# 3 remote_port

/usr/bin/ssh -oExitOnForwardFailure=yes -f -N -R $3:localhost:$1 $2

