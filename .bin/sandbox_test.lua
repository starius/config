local sandbox = require 'sandbox'

string.hack = function() print("Hacked") end
code = [[ ("just string"):hack() ]]
sandbox.load(sandbox.env(), code)()
