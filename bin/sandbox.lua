#!/usr/bin/env lua

-- based on http://stackoverflow.com/a/6982080

local sandbox = {}

-- sample sandbox environment
sandbox.env = function(more_functions)
  local env = {
  _VERSION = _VERSION,
  select = select,
  ipairs = ipairs,
  next = next,
  pairs = pairs,
  pcall = pcall,
  tonumber = tonumber,
  tostring = tostring,
  type = type,
  unpack = unpack or table.unpack,
  string = {
      byte = string.byte, char = string.char,
      format = string.format,
      len = string.len, lower = string.lower,
      reverse = string.reverse, sub = string.sub,
      upper = string.upper },
  table = {
      insert = table.insert, maxn = table.maxn,
      remove = table.remove, sort = table.sort,
      unpack = table.unpack },
  math = {
      abs = math.abs, acos = math.acos, asin = math.asin,
      atan = math.atan, atan2 = math.atan2, ceil = math.ceil,
      cos = math.cos, cosh = math.cosh, deg = math.deg,
      exp = math.exp, floor = math.floor,
      fmod = math.fmod, frexp = math.frexp, huge = math.huge,
      ldexp = math.ldexp, log = math.log, log10 = math.log10,
      max = math.max, min = math.min, modf = math.modf,
      pi = math.pi, pow = math.pow, rad = math.rad,
      random = math.random, sin = math.sin, sinh = math.sinh,
      sqrt = math.sqrt, tan = math.tan, tanh = math.tanh },
  os = {
      clock = os.clock, difftime = os.difftime,
      time = os.time },
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
        env.string.find = string.find
        env.string.gmatch = string.gmatch
        env.string.gsub = string.gsub
        env.string.match = string.match
        env.string.rep = string.rep
    end
    return env
end

sandbox.protect = function(env, code)
    env = env or sandbox.env()
    if type(code) ~= 'string' then
        return nil, 'Type of code should be string'
    end
    if code:byte(1) == 27 then
        return nil, 'Bytecode is not allowed'
    end
    if _VERSION == 'Lua 5.2' then
        return load(code, 'sandbox', 't', env)
    elseif _VERSION == 'Lua 5.1' then
        local f, message = loadstring(code, 'sandbox')
        if not f then
            return nil, message
        end
        setfenv(f, env)
        return f
    else
        return nil, 'Implemented in Lua 5.1 and 5.2 only'
    end
end

sandbox.run_code = function(env, code, ...)
    local f, message = sandbox.protect(env, code)
    if not f then
        return nil, message
    end
    local results = {pcall(f, ...)}
    return unpack(results)
end

sandbox.run_file = function(env, fname, ...)
    local input_file = io.open(fname, 'r')
    local code = input_file:read('*a')
    input_file:close()
    return sandbox.run_code(env, code, ...)
end

-- http://stackoverflow.com/a/4521960
if not pcall(debug.getlocal, 4, 1) then
    local fname = assert(arg[1], 'Provide .lua file to run')
    local status, results = sandbox.run_file(nil, fname)
    if not status then
        print(results)
    end
end

return sandbox

