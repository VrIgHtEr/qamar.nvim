local qamar = {}

function qamar.run()
    do
        local to_unload = {}
        for k in pairs(package.loaded) do
            if #k >= 6 and k:sub(1, 6) == 'qamar.' then
                table.insert(to_unload, k)
            end
        end
        for _, k in ipairs(to_unload) do
            package.loaded[k] = nil
        end
    end

    local string = require 'toolshed.util.string'
    local buffer = require 'qamar.token.buffer'
    local tokenizer = require 'qamar.token'

    local s = [====[
::lbl::   -- this is a comment

--[[
this is a comment 
as well]] x = 7 + 3
local y = '😊😊😊😊😊😊😊'
    ]====]
    local t = tokenizer(buffer(string.filteredcodepoints(s)))

    while t.peek() do
        print(vim.inspect(t.take()))
    end
end

return qamar
