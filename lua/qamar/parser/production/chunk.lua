local cfg = require 'qamar.config'
return function(self)
    cfg.reset()
    if self:peek() then
        local parser = function()
            local ret = self:block()
            local peek = self.la[self.la.size()] or nil
            if cfg.indentlevel() ~= 0 then
                error(
                    '\n****************************************************************\n****************************************************************\n****************************************************************\n****************************************************************\n****************************************************************\n****************************************************************\n****************************************************************\n****************************************************************\nINVALID ENDING INDENT LEVEL: '
                        .. cfg.indentlevel()
                )
            end
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
        end
        --[[        setfenv(
            parser,
            setmetatable({
                begin = function()
                    self:begin()
                end,
                undo = function()
                    self:undo()
                end,
                commit = function()
                    self:commit()
                end,
                take = function(amt)
                    self:take(amt)
                end,
                begintake = function(amt)
                    self:begintake(amt)
                end,
                peek = function(skip)
                    self:peek(skip)
                end,
            }, { __metatable = function() end, index = _G })
        )
        ]]
        return parser()
    else
        return setmetatable({}, {
            __tostring = function()
                return ''
            end,
        })
    end
end
