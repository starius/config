#!/usr/bin/env lua

-- http://www.nirsoft.net/countryip/fr.html

for line in io.lines() do
    local start, stop, number =
        line:match("^([^,]+),([^,]+),(%d+).*")
    if start then
        local net = math.log(number) / math.log(2)
        net = math.floor(net)
        print(('ExitPolicy reject %s/%i:*')
            :format(start, net))
    end
end
