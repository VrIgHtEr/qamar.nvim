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

local p = require 'qamar.parser'
local peek = p.peek
local take = p.take
local commit = p.commit
local undo = p.undo
local begintake = p.begintake

return function(self)
    local kw_for = peek(self)
    if kw_for and kw_for.type == token.kw_for then
        begintake(self)
        local varname = name(self)
        if varname then
            local tok = take(self)
            if tok and tok.type == token.assignment then
                local start = expression(self)
                if start then
                    tok = take(self)
                    if tok and tok.type == token.comma then
                        local finish = expression(self)
                        if finish then
                            local increment = nil
                            tok = peek(self)
                            if tok and tok.type == token.comma then
                                begintake(self)
                                increment = expression(self)
                                if increment then
                                    commit(self)
                                else
                                    undo(self)
                                end
                            end
                            tok = take(self)
                            if tok and tok.type == token.kw_do then
                                local body = block(self)
                                tok = take(self)
                                if tok and tok.type == token.kw_end then
                                    commit(self)
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
        undo(self)
    end
end
