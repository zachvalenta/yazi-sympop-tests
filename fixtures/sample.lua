-- Sample Lua file for testing

local M = {}

-- Local helper function
local function helper()
    return 42
end

-- Another local function
local function validate(x)
    return x > 0
end

-- Module function (dot style)
function M.new(value)
    return { value = value }
end

function M.get_value(self)
    return self.value
end

-- Module method (colon style)
function M:init()
    self.ready = true
end

function M:process(data)
    return data
end

-- Top-level bare function
function setup()
    print("setup")
end

function teardown()
    print("teardown")
end

return M
