local sandbox = require 'sandbox'

local logged_in = false

local function checkPassword(password)
    if password:match("secret") then
        logged_in = true
    end
end

local untrusted = [[
    local identify = ...
    local str = "string"
    local dump = str.dump
    -- returns bytecode of checking function (checkPassword,
    -- identify itself) which contains the password
    return dump(identify)
]]

local protected = sandbox.load(sandbox.env(), untrusted)
protected(checkPassword)

assert(not logged_in)
