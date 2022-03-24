local tokenizers = {
    require 'qamar.tokenizer.token.comment',
    require 'qamar.tokenizer.token.name',
    require 'qamar.tokenizer.token.keyword',
    require 'qamar.tokenizer.token.number',
    require 'qamar.tokenizer.token.string',
    require 'qamar.tokenizer.token.symbol',
}
local token = require 'qamar.tokenizer.types'

return function(stream)
    ::restart::
    if stream.peek() then
        for _, x in ipairs(tokenizers) do
            local ret = x(stream)
            if ret then
                if ret.type == token.comment then
                    goto restart
                end
                return ret
            end
        end
        stream.skipws()
        if stream.peek() then
            local preview = {}
            stream.begin()
            for i = 1, 30 do
                local t = stream.take()
                if not t then
                    break
                end
                preview[i] = t
            end
            stream.undo()
            error('invalid token on line ' .. stream.pos().row .. ', col ' .. stream.pos().col .. ' ' .. vim.inspect(table.concat(preview)))
        end
    end
end
