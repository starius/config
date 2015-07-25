#!/usr/bin/env lua

-- based on http://stackoverflow.com/a/6982080

local sandbox = {}

sandbox.string = function(more_functions)
    local s = {
        byte=string.byte, char=string.char,
        format=string.format, len=string.len,
        lower=string.lower, reverse=string.reverse,
        sub=string.sub, upper=string.upper,
    }
    if more_functions then
        s.find = string.find
        s.gmatch = string.gmatch
        s.gsub = string.gsub
        s.match = string.match
        s.rep = string.rep
    end
    return s
end

-- sample sandbox environment
sandbox.env = function(more_functions)
    local env = {
        _VERSION=_VERSION, select=select, ipairs=ipairs,
        next=next, pairs=pairs, pcall=pcall,
        tonumber=tonumber, tostring=tostring,
        type=type,
        unpack = unpack,
        string = sandbox.string(more_functions),
        table = {
            insert=table.insert, maxn=table.maxn,
            remove=table.remove, sort=table.sort,
            unpack=table.unpack,
        },
        math = {
            abs=math.abs, acos=math.acos, asin=math.asin,
            atan=math.atan, atan2=math.atan2, ceil=math.ceil,
            cos=math.cos, cosh=math.cosh, deg=math.deg,
            exp=math.exp, floor=math.floor,
            fmod=math.fmod, frexp=math.frexp, huge=math.huge,
            ldexp=math.ldexp, log=math.log, log10=math.log10,
            max=math.max, min=math.min, modf=math.modf,
            pi=math.pi, pow=math.pow, rad=math.rad,
            random=math.random, sin=math.sin, sinh=math.sinh,
            sqrt=math.sqrt, tan=math.tan, tanh=math.tanh,
        },
        os = {
            clock=os.clock, time=os.time,
            difftime=os.difftime,
        },
    }
    if more_functions then
        env.print = print
        env.coroutine = {
            create=coroutine.create,
            resume=coroutine.resume,
            running=coroutine.running,
            status=coroutine.status,
            wrap=coroutine.wrap,
        }
    end
    return env
end

sandbox.replace_string = function(string_lib)
    local string_saved = debug.getmetatable("")
    debug.setmetatable("", {__index = string_lib})
    return string_saved
end

sandbox.load = function(env, code, string_lib)
    env = env or sandbox.env()
    string_lib = string_lib or sandbox.string()
    if type(code) ~= 'string' then
        return nil, 'Type of code should be string'
    end
    if code:byte(1) == 27 then
        return nil, 'Bytecode is not allowed'
    end
    local func
    if _VERSION == 'Lua 5.2' or _VERSION == 'Lua 5.3' then
        func = load(code, 'sandbox', 't', env)
    elseif _VERSION == 'Lua 5.1' then
        local f, message = loadstring(code, 'sandbox')
        if not f then
            return nil, message
        end
        setfenv(f, env)
        func = f
    else
        return nil, 'Implemented in Lua 5.1, 5.2, 5.3 only'
    end
    local unpack = unpack or table.unpack
    return function(...)
        local string_saved = sandbox.replace_string(string_lib)
        local results = {pcall(func(...))}
        table.remove(results, 1) -- pcall's status
        sandbox.replace_string(string_saved)
        return unpack(results)
    end
end

sandbox.antidos = function(f, timeout, memory)
    return function(...)
        local clock0 = os.clock()
        local mem0 = collectgarbage("count")
        local checktime = function()
            if os.clock() - clock0 > timeout then
                error("CPU time exhausted")
            end
            if collectgarbage("count") - mem0 > memory then
                error("Memory exhausted")
            end
        end
        local hook, mask, count = debug.gethook()
        debug.sethook(checktime, "", 1e3)
        local results = {pcall(f, ...)}
        -- restore original hook if any
        debug.sethook(hook, mask, count)
        local unpack = unpack or table.unpack
        return unpack(results)
    end
end

-- http://stackoverflow.com/a/4521960
if not pcall(debug.getlocal, 4, 1) then
    local fname = assert(arg[1], 'Provide .lua file to run')
    local input_file = io.open(fname, 'r')
    local code = input_file:read('*a')
    input_file:close()
    local env = sandbox.env()
    env.print = print
    local f, message = sandbox.load(env, code)
    if not f then
        print(message)
    end
    f = sandbox.antidos(f, 10, 100000) -- 10 seconds, 100 mb
    local results = {f()}
    if not results[1] then
        print(results[2])
    else
        table.remove(results, 1)
        local unpack = unpack or table.unpack
        print(unpack(results))
    end
end

return sandbox
