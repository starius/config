#!/usr/bin/env lua

-- based on http://stackoverflow.com/a/6982080

local sandbox = {}

-- sample sandbox environment
sandbox.env = {
  print = print,
  select = select,
  ipairs = ipairs,
  next = next,
  pairs = pairs,
  pcall = pcall,
  tonumber = tonumber,
  tostring = tostring,
  type = type,
  unpack = unpack or table.unpack,
  coroutine = {
      create = coroutine.create, resume = coroutine.resume,
      running = coroutine.running, status = coroutine.status,
      wrap = coroutine.wrap },
  string = {
      byte = string.byte, char = string.char,
      find = string.find, format = string.format,
      gmatch = string.gmatch, gsub = string.gsub,
      len = string.len, lower = string.lower,
      match = string.match, rep = string.rep,
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

sandbox.run_func = function(env, f, ...)
    env = env or sandbox.env
    local unpack = unpack or table.unpack
    local pcall = pcall
    if not f then
        return nil
    end
    if _VERSION == 'Lua 5.2' then
        local _ENV = env
        local results = {pcall(f, ...)}
        return unpack(results)
    elseif _VERSION == 'Lua 5.1' then
        local orig_env = getfenv(f)
        setfenv(f, env)
        local results = {pcall(f, ...)}
        setfenv(f, orig_env)
        return unpack(results)
    else
        return false, 'Implemented in Lua 5.1 and 5.2 only'
    end
end

sandbox.run_code = function(env, code, ...)
    if code:byte(1) == 27 then
        return false, 'Bytecode is not allowed'
    end
    local f, message = loadstring(code)
    if not f then
        return false, message
    end
    return sandbox.run_func(env, f, ...)
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

