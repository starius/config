# args:
# 1 local_port
# 2 host
# 3 remote_port

netstat -lnt | grep -q 127.0.0.1:$1
if [[ $? -ne 0 ]]; then
    echo Creating new tunnel connection
    /usr/bin/ssh -f -N -L $1:localhost:$3 $2
    if [[ $? -eq 0 ]]; then
        echo Tunnel to hostb created successfully
    else
        echo An error occurred creating a tunnel to hostb RC was $?
    fi
fi

