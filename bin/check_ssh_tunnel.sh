/usr/bin/ssh $1 netstat -lnt | grep -q 127.0.0.1:$2
if [[ $? -ne 0 ]]; then
    echo Creating new tunnel connection
    /usr/bin/ssh -f -N -R $2:localhost:22 $1
    if [[ $? -eq 0 ]]; then
        echo Tunnel to hostb created successfully
    else
        echo An error occurred creating a tunnel to hostb RC was $?
    fi
fi

