#!/usr/bin/lua

for line in io.stdin:lines() do
    local fields = {}
    for field in line:gmatch('([^\t]+)') do
        table.insert(fields, field)
    end
    table.sort(fields)
    print(table.concat(fields, '\t'))
end
