local tokenizers = {
    require 'qamar.tokenizer.token.comment',
    require 'qamar.tokenizer.token.name',
    require 'qamar.tokenizer.token.keyword',
    require 'qamar.tokenizer.token.number',
    require 'qamar.tokenizer.token.string',
    require 'qamar.tokenizer.token.symbol',
}
local token = require 'qamar.tokenizer.types'
local s = require 'qamar.tokenizer.char_stream'
local spos = s.pos
local ipairs = ipairs
local concat = table.concat
local peek = s.peek
local begin = s.begin
local take = s.take
local undo = s.undo
local skipws = s.skipws

return function(self)
    ::restart::
    if peek(self) then
        for _, x in ipairs(tokenizers) do
            local ret = x(self)
            if ret then
                if ret.type == token.comment then
                    goto restart
                end
                return ret
            end
        end
        skipws(self)
        if peek(self) then
            local preview = {}
            begin(self)
            for i = 1, 30 do
                local t = take(self)
                if not t then
                    break
                end
                preview[i] = t
            end
            undo(self)
            error('invalid token on line ' .. spos(self).row .. ', col ' .. spos(self).col .. ' ' .. vim.inspect(concat(preview)))
        end
    end
end
