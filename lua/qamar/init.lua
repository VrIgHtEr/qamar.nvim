local qamar = {}

local function inspect(c)
    return (vim.inspect(c):gsub('\r\n', '\n'):gsub('\r', '\n'):gsub('\n%s*', ' '))
end

local function rpad(s, l)
    s = tostring(s)
    while #s < l do
        s = s .. ' '
    end
    return s
end

local function lpad(s, l)
    s = tostring(s)
    while #s < l do
        s = ' ' .. s
    end
    return s
end

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

    local ppp = require 'qamar.parser'(
        require 'qamar.tokenizer'(require 'qamar.tokenizer.buffer'(require('toolshed.util.string').codepoints 'a+-b*-3^((4 or 7)+6)^7+4+(7+5)'))
    )
    local parsed = ppp.expression()
    print(parsed)

    local string = require 'toolshed.util.string'
    local buffer = require 'qamar.tokenizer.buffer'
    local tokenizer = require 'qamar.tokenizer'
    local token_names = require 'qamar.tokenizer.token_names'

    local s = [====[
::lbl::   -- this is a comment

--[[
this is a comment 
as well]] x = 7 + 3
local y = '😊😊😊😊😊😊😊'
    ]====]
    s = require('toolshed.util').read_file(vim.fn.stdpath 'data' .. '/site/pack/vrighter/opt/qamar.nvim/lua/qamar/tokenizer/buffer.lua')
    local t = tokenizer(buffer(string.filteredcodepoints(s)))
    t.begin()
    while t.peek() do
        local x = t.take()
        print(
            rpad(token_names[x.type], 15)
                .. ' '
                .. lpad(x.pos.left.row, 5)
                .. ','
                .. rpad(x.pos.left.col, 5)
                .. ' - '
                .. lpad(x.pos.right.row, 5)
                .. ','
                .. rpad(x.pos.right.col, 5)
                .. ' '
                .. inspect(x.value)
        )
    end
end

return qamar
