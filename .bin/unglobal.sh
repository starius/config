# adds line like "local print = print" before Lua file
# (makes all standard global variables local)
# Usage:
# $ unglobal.sh 1.lua [ 2.lua ... ]
# WARNING: this can decrease performance

tmpname=`mktemp`

for f in $@; do
    names=$(luac -l -p $f | grep ETGLOBAL | \
        awk '{print $7}' | sort -u | \
        egrep "string|xpcall|package|tostring|print|os|unpack|require|getfenv|setmetatable|next|assert|tonumber|io|rawequal|collectgarbage|getmetatable|module|rawset|math|debug|pcall|table|newproxy|type|coroutine|_G|select|gcinfo|pairs|rawget|loadstring|ipairs|_VERSION|dofile|setfenv|load|error|loadfile" | \
        sed ':begin;$!N;s/\n/,/g;tbegin;P;D')
    if [ -n "$names" ]; then
        echo "local $names =" >  $tmpname
        echo "  $names" >> $tmpname
        echo '' >> $tmpname
        cat $f >> $tmpname
        cat $tmpname > $f
    fi
done

rm $tmpname
