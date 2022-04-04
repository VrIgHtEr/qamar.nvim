return function(self)
    if self:peek() then
        self.cache = {}
        local ret = self:block()
        local peek = self.la[self.la.size()] or nil
        if ret then
            if peek then
                error('UNMATCHED TOKEN: ' .. tostring(peek) .. ' at line ' .. peek.pos.left.row .. ', col ' .. peek.pos.left.col)
            end
            return ret
        elseif peek then
            error('UNMATCHED TOKEN: ' .. tostring(peek) .. ' at line ' .. peek.pos.left.row .. ', col ' .. peek.pos.left.col)
        else
            error('PARSE_FAILURE' .. ' at line ' .. peek.pos.left.row .. ', col ' .. peek.pos.left.col)
        end
    else
        return setmetatable({}, {
            __tostring = function()
                return ''
            end,
        })
    end
end
