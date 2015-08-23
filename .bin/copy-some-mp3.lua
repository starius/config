-- lua copy-some-mp3.lua seen.txt dest

local seen = arg[1]
local dest = arg[2]

local seen_set = {}
for file in io.open(seen):lines() do
    seen_set[file] = 1
end

local sizes = {} -- in KB
local all = {}
for entry in io.popen('du -s *.mp3'):lines() do
    local size, file = entry:match('^(%d+)%s(.*)$')
    if not seen_set[file] then
        table.insert(all, file)
    end
    sizes[file] = tonumber(size)
end

math.randomseed(os.time())

local MAX_SIZE = 3400000 -- in KB
local copied = 0
while copied < MAX_SIZE and #all > 0 do
    local i = math.random(1, #all)
    local file = all[i]
    all[i] = all[#all]
    all[#all] = nil
    os.execute("cp '" .. file .. "' " .. dest)
    copied = copied + sizes[file]
end
