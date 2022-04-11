---@class node_functioncall:node_expression
---@field left node
---@field args node
---@field self string

local token, node = require 'qamar.tokenizer.types', require 'qamar.parser.types'
local tconcat, tinsert = require('qamar.util.table').tconcat, require('qamar.util.table').tinsert
local setmetatable = setmetatable

local tlparen = token.lparen
local trparen = token.rparen
local tlbrace = token.lbrace
local tname = token.name
local tstring = token.string
local tcolon = token.colon
local ntableconstructor = node.tableconstructor
local nstring = node.string
local nname = node.name
local ntable_nameaccess = node.table_nameaccess
local ntable_rawaccess = node.table_rawaccess
local nfunctioncall = node.functioncall
local nsubexpression = node.subexpression
local tostring = tostring
local N = require 'qamar.parser.node_expression'
local range = require 'qamar.util.range'

local MT = {
    ---@param self node_functioncall
    ---@return string
    __tostring = function(self)
        local ret = { self.left }
        if self.self then
            tinsert(ret, ':', self.self)
        end
        local paren = #self.args ~= 1 or (self.args[1].type ~= ntableconstructor and self.args[1].type ~= nstring)
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

local tableconstructor = require 'qamar.parser.parselet.tableconstructor'
local atom = require 'qamar.parser.parselet.atom'

local p = require 'qamar.parser'
local peek = p.peek
local take = p.take
local explist
explist = function(self)
    explist = require('qamar.parser.production.explist').parser
    return explist(self)
end

local mtempty = {
    __tostring = function()
        return ''
    end,
}

local mtnonempty = {
    __tostring = function(x)
        return tostring(x[1])
    end,
}

---parselet to consume a function call
---@param self parselet
---@param parser parser
---@param left node_expression
---@param tok token
---@return node_functioncall|nil
return function(self, parser, left, tok)
    if left.type == nname or left.type == ntable_nameaccess or left.type == ntable_rawaccess or left.type == nfunctioncall or left.type == nsubexpression then
        local sname, arglist, right = false, nil, nil
        if tok.type == tlparen then
            local args = explist(parser) or setmetatable({}, mtempty)
            if peek(parser) then
                local rparen = take(parser)
                if rparen.type == trparen then
                    arglist = args
                    right = rparen.pos.right
                end
            end
        elseif tok.type == tlbrace then
            local arg = tableconstructor(self, parser, tok)
            if arg then
                arglist = setmetatable({ arg }, mtnonempty)
                right = arg.pos.right
            end
        elseif tok.type == tstring then
            local arg = atom(self, parser, tok)
            if arg then
                arglist = setmetatable({ arg }, mtnonempty)
                right = arg.pos.right
            end
        elseif tok.type == tcolon then
            if peek(parser) then
                local name = take(parser)
                if name.type == tname then
                    sname = name.value

                    local next = peek(parser)
                    if next then
                        take(parser)
                        if next.type == tlparen then
                            local args = explist(parser) or setmetatable({}, mtempty)
                            if peek(parser) then
                                local rparen = take(parser)
                                if rparen.type == trparen then
                                    arglist = args
                                    right = rparen.pos.right
                                end
                            end
                        elseif next.type == tlbrace then
                            local arg = tableconstructor(self, parser, next)
                            if arg then
                                arglist = setmetatable({ arg }, mtnonempty)
                                right = arg.pos.right
                            end
                        elseif next.type == tstring then
                            local arg = atom(self, parser, next)
                            if arg then
                                arglist = setmetatable({ arg }, mtnonempty)
                                right = arg.pos.right
                            end
                        end
                    end
                end
            end
        end
        if arglist then
            local ret = N(nfunctioncall, range(left.pos.left, right), self.precedence, self.right_associative, MT)
            ret.left = left
            ret.args = arglist
            ret.self = sname
            return ret
        end
    end
end
