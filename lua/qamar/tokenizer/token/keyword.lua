local token = require 'qamar.tokenizer.types'

local keywords = require 'qamar.tokenizer.token.keywords'

local stream = require 'qamar.tokenizer.char_stream'
local begin = stream.begin
local skipws = stream.skipws
local suspend_skip_ws = stream.suspend_skip_ws
local spos = stream.pos
local try_consume_string = stream.try_consume_string
local resume_skip_ws = stream.resume_skip_ws
local undo = stream.undo
local commit = stream.commit
local alphanumeric = stream.alphanumeric
local ipairs = ipairs
local range = require 'qamar.util.range'
local T = require 'qamar.tokenizer.token'

---tries to match and consume a lua keyword
---@param self char_stream
---@return string|nil
local function parser(self)
    for _, x in ipairs(keywords) do
        if try_consume_string(self, x) then
            return x
        end
    end
end

---tries to match and consume a lua keyword
---@param self char_stream
---@return token|nil
return function(self)
    begin(self)
    skipws(self)
    local pos = spos(self)
    local ret = parser(self)
    if ret then
        begin(self)
        suspend_skip_ws(self)
        local next = alphanumeric(self)
        resume_skip_ws(self)
        undo(self)
        if not next then
            commit(self)
            resume_skip_ws(self)
            return T(token['kw_' .. ret], ret, range(pos, spos(self)))
        end
    end
    undo(self)
end
