#!/usr/bin/env lua

local data = io.stdin:read('*a')
data = data:gsub('.', function(c)
    local byte = c:byte(1)
    if c == '"' then
        return [[\"]]
    elseif c == [[\]] then
        return [[\\]]
    elseif byte >= 32 and byte <= 126 then
        return c
    elseif c == '\n' then
        return [[\n"]] .. '\n' .. [["]]
    elseif c == '\t' then
        return [[\t]]
    else
        return ([[\%3o]]):format(byte)
    end
end)
io.stdout:write('"', data, '"\n')
