local token = require 'qamar.tokenizer.types'
local s = require 'qamar.tokenizer.char_stream'
local alphanumeric = s.ALPHANUMERIC
local alpha = s.ALPHA
local keywords = require 'qamar.tokenizer.token.keywords'

local MT = {
    __tostring = function(self)
        return self.value
    end,
}
return function(self)
    self:begin()
    self:skipws()
    local pos = self:pos()
    self:suspend_skip_ws()
    local ret = {}
    local idx = 0
    local t = alpha(self)
    if t == nil then
        self:undo()
        self:resume_skip_ws()
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
    ret = table.concat(ret)
    if keywords[ret] then
        self:undo()
        self:resume_skip_ws()
        return nil
    end
    self:commit()
    self:resume_skip_ws()
    return setmetatable({
        value = ret,
        type = token.name,
        pos = {
            left = pos,
            right = self:pos(),
        },
    }, MT)
end
