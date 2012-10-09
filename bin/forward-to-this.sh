# args:
# 1 local_port
# 2 host
# 3 remote_port

/usr/bin/ssh $2 netstat -lnt | grep -q 127.0.0.1:$3
if [[ $? -ne 0 ]]; then
    echo Creating new tunnel connection
    /usr/bin/ssh -f -N -R $3:localhost:$1 $2
    if [[ $? -eq 0 ]]; then
        echo Tunnel to hostb created successfully
    else
        echo An error occurred creating a tunnel to hostb RC was $?
    fi
fi

