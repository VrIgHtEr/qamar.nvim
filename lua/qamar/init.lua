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
    local buffer = require 'qamar.buffer'
    local tokenizer = require 'qamar.token'

    local s = '::lbl::'
    local t = tokenizer(buffer(string.filteredcodepoints(s)))

    while true do
        local x = t.peek()
        if not x then
            break
        end
        print(vim.inspect(t.take()))
    end
end

return qamar
