local token, string_token = require 'qamar.tokenizer.types', require 'qamar.tokenizer.token.string'

local stream = require 'qamar.tokenizer.char_stream'
local begin = stream.begin
local skipws = stream.skipws
local suspend_skip_ws = stream.suspend_skip_ws
local spos = stream.pos
local try_consume_string = stream.try_consume_string
local resume_skip_ws = stream.resume_skip_ws
local undo = stream.undo
local commit = stream.commit
local peek = stream.peek
local take = stream.take
local concat = table.concat

return function(self)
    begin(self)
    skipws(self)
    suspend_skip_ws(self)
    local pos = spos(self)
    local comment = try_consume_string(self, '--')
    if not comment then
        resume_skip_ws(self)
        undo(self)
        return nil
    end
    local ret = string_token(self, true)
    if ret then
        ret.type = token.comment
        ret.pos.left = pos
        resume_skip_ws(self)
        commit(self)
        return ret
    end
    ret = {}
    local idx = 0
    while true do
        local c = peek(self)
        if not c or c == '\n' then
            break
        end
        idx = idx + 1
        ret[idx] = take(self)
    end
    commit(self)
    resume_skip_ws(self)
    return {
        value = concat(ret),
        type = token.comment,
        pos = {
            left = pos,
            right = spos(self),
        },
    }
end
