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

if not arg[1] then
    print "Usage: ldd-rec.lua filenames"
else
    local deps_set = {}
    for i = 1, #arg do
        local file = arg[i]
        local deps = lddRec(file)
        for _, dep in ipairs(deps) do
            deps_set[dep] = true
        end
    end
    for dep, _ in pairs(deps_set) do
        print(dep)
    end
end
