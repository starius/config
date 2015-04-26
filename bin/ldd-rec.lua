#!/usr/bin/env lua

-- Usage: ldd-rec.lua filename

local function ldd(filename)
    local deps = {}
    local f = io.popen('ldd ' .. filename, 'r')
    for line in f:lines() do
        local dep = line:match('=> ([^ ]+)')
        if dep then
            table.insert(deps, dep)
        end
    end
    f:close()
    return deps
end

local function lddRec(start)
    local seen = {}
    local pending = {start}
    while #pending > 0 do
        local filename = table.remove(pending)
        if not seen[filename] then
            seen[filename] = true
            local deps = ldd(filename)
            for _, dep in ipairs(deps) do
                table.insert(pending, dep)
            end
        end
    end
    seen[start] = nil
    local deps = {}
    for filename in pairs(seen) do
        table.insert(deps, filename)
    end
    return deps
end

local start = arg[1]

if not start then
    print "Usage: ldd-rec.lua filename"
else
    local deps = lddRec(start)
    for _, dep in ipairs(deps) do
        print(dep)
    end
end
