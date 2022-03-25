local token, node = require 'qamar.tokenizer.types', require 'qamar.parser.types'
local tconcat, tinsert = require('qamar.util.table').tconcat, require('qamar.util.table').tinsert

local MT = {
    __tostring = function(self)
        local ret = { self.left }
        if self.self then
            tinsert(ret, ':', self.self)
        end
        local paren = #self.args ~= 1 or (self.args[1].type ~= node.tableconstructor and self.args[1].type ~= node.string)
        if paren then
            tinsert(ret, '(')
        end
        tinsert(ret, self.args)
        if paren then
            tinsert(ret, ')')
        end
        return tconcat(ret)
    end,
}

local tableconstructor = require 'qamar.parser.parselet2.tableconstructor'
local atom = require 'qamar.parser.parselet2.atom'

return function(self, parser, left, tok)
    if
        left.type == node.name
        or left.type == node.table_nameaccess
        or left.type == node.table_rawaccess
        or left.type == node.functioncall
        or left.type == node.subexpression
    then
        local sname, arglist, right = false, nil, nil
        if tok.type == token.lparen then
            local args = parser:explist()
                or setmetatable({}, {
                    __tostring = function()
                        return ''
                    end,
                })
            if parser:peek() then
                local rparen = parser:take()
                if rparen.type == token.rparen then
                    arglist = args
                    right = rparen.pos.right
                end
            end
        elseif tok.type == token.lbrace then
            local arg = tableconstructor(self, parser, tok)
            if arg then
                arglist = setmetatable({ arg }, {
                    __tostring = function(x)
                        return tostring(x[1])
                    end,
                })
                right = arg.pos.right
            end
        elseif tok.type == token.string then
            local arg = atom(self, parser, tok)
            if arg then
                arglist = setmetatable({ arg }, {
                    __tostring = function(x)
                        return tostring(x[1])
                    end,
                })
                right = arg.pos.right
            end
        elseif tok.type == token.colon then
            if parser:peek() then
                local name = parser:take()
                if name.type == token.name then
                    sname = name.value

                    local next = parser:peek()
                    if next then
                        parser:take()
                        if next.type == token.lparen then
                            local args = parser:explist()
                                or setmetatable({}, {
                                    __tostring = function()
                                        return ''
                                    end,
                                })
                            if parser:peek() then
                                local rparen = parser:take()
                                if rparen.type == token.rparen then
                                    arglist = args
                                    right = rparen.pos.right
                                end
                            end
                        elseif next.type == token.lbrace then
                            local arg = tableconstructor(self, parser, next)
                            if arg then
                                arglist = setmetatable({ arg }, {
                                    __tostring = function(x)
                                        return tostring(x[1])
                                    end,
                                })
                                right = arg.pos.right
                            end
                        elseif next.type == token.string then
                            local arg = atom(self, parser, next)
                            if arg then
                                arglist = setmetatable({ arg }, {
                                    __tostring = function(x)
                                        return tostring(x[1])
                                    end,
                                })
                                right = arg.pos.right
                            end
                        end
                    end
                end
            end
        end
        if arglist then
            return setmetatable({
                type = node.functioncall,
                left = left,
                args = arglist,
                self = sname,
                precedence = self.precedence,
                right_associative = self.right_associative,
                pos = { left = left.pos.left, right = right },
            }, MT)
        end
    end
end
