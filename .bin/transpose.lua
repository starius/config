#!/usr/bin/lua

for line in io.stdin:lines() do
    for field in line:gmatch('([^\t]+)') do
        print(field)
    end
end
