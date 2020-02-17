local x = 1

local env = setmetatable({x = x}, {__index = _ENV})
local f = load([[
    gv = 3
    return table
]], "=load", "bt", env)
print(f(), gv)