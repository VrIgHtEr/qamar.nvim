local token, string_token = require 'qamar.tokenizer.types', require 'qamar.tokenizer.token.string'

return function(self)
    self:begin()
    self:skipws()
    self:suspend_skip_ws()
    local pos = self:pos()
    local comment = self:try_consume_string '--'
    if not comment then
        self:resume_skip_ws()
        self:undo()
        return nil
    end
    local ret = string_token(self, true)
    if ret then
        ret.type = token.comment
        ret.pos.left = pos
        self:resume_skip_ws()
        self:commit()
        return ret
    end
    ret = {}
    local idx = 0
    while true do
        local c = self:peek()
        if not c or c == '\n' then
            break
        end
        idx = idx + 1
        ret[idx] = self:take()
    end
    self:commit()
    self:resume_skip_ws()
    return {
        value = table.concat(ret),
        type = token.comment,
        pos = {
            left = pos,
            right = self:pos(),
        },
    }
end
