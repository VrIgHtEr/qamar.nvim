local token = require 'qamar.tokenizer.types'
local s = require 'qamar.tokenizer.char_stream'
local alpha = s.alpha
local keywords = require 'qamar.tokenizer.token.keywords'

local begin = s.begin
local skipws = s.skipws
local suspend_skip_ws = s.suspend_skip_ws
local spos = s.pos
local resume_skip_ws = s.resume_skip_ws
local undo = s.undo
local commit = s.commit
local alphanumeric = s.alphanumeric
local concat = table.concat
local tname = token.name
local range = require 'qamar.util.range'
local T = require 'qamar.tokenizer.token'

---tries to match and consume a lua name
---@param self char_stream
---@return token|nil
return function(self)
    begin(self)
    skipws(self)
    local pos = spos(self)
    suspend_skip_ws(self)
    local ret = {}
    local idx = 0
    local t = alpha(self)
    if t == nil then
        undo(self)
        resume_skip_ws(self)
        return nil
    end
    while true do
        idx = idx + 1
        ret[idx] = t
        t = alphanumeric(self)
        if t == nil then
            break
        end
    end
    ret = concat(ret)
    if keywords[ret] then
        undo(self)
        resume_skip_ws(self)
        return nil
    end
    commit(self)
    resume_skip_ws(self)
    return T(tname, ret, range(pos, spos(self)))
end
