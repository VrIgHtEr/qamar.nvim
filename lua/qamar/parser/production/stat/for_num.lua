local util = require 'qamar.util'
local cfg = require 'qamar.config'
local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat
local tinsert = require('qamar.util.table').tinsert

local name = require 'qamar.parser.production.name'
local expression = require 'qamar.parser.production.expression'
local block = require 'qamar.parser.production.block'

local mt = {
    __tostring = function(s)
        local ret = { 'for', s.name, '=', s.start, ',', s.finish }
        if s.increment then
            tinsert(ret, ',', s.increment)
        end
        tinsert(ret, 'do', s.body, 'end')
        return tconcat(ret)
    end,
}

return function(self)
    if cfg.trace then
        print(util.get_script_path())
    end
    local kw_for = self:peek()
    if kw_for and kw_for.type == token.kw_for then
        self:begintake()
        local varname = name(self)
        if varname then
            local tok = self:take()
            if tok and tok.type == token.assignment then
                local start = expression(self)
                if start then
                    tok = self:take()
                    if tok and tok.type == token.comma then
                        local finish = expression(self)
                        if finish then
                            local increment = nil
                            tok = self:peek()
                            if tok and tok.type == token.comma then
                                self:begintake()
                                increment = expression(self)
                                if increment then
                                    self:commit()
                                else
                                    self:undo()
                                end
                            end
                            tok = self:take()
                            if tok and tok.type == token.kw_do then
                                local body = block(self)
                                tok = self:take()
                                if tok and tok.type == token.kw_end then
                                    self:commit()
                                    return setmetatable({
                                        name = varname,
                                        start = start,
                                        finish = finish,
                                        increment = increment,
                                        body = body,
                                        type = n.stat_for_num,
                                        pos = { left = kw_for.pos.left, right = tok.pos.right },
                                    }, mt)
                                end
                            end
                        end
                    end
                end
            end
        end
        self:undo()
    end
end
