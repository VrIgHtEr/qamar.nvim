local util = require 'qamar.util'
local cfg = require 'qamar.config'
local token = require 'qamar.tokenizer.types'
local n = require 'qamar.parser.types'
local tconcat = require('qamar.util.table').tconcat
local tinsert = require('qamar.util.table').tinsert

local mt = {
    __tostring = function(self)
        local ret = { 'local', self.names }
        if self.values then
            tinsert(ret, '=', self.values)
        end
        return tconcat(ret)
    end,
}

local attnamelist = require 'qamar.parser.production.attnamelist'
local explist = require 'qamar.parser.production.explist'

return function(self)
    if cfg.trace then
        print(util.get_script_path())
    end
    local tok = self:peek()
    if tok and tok.type == token.kw_local then
        self:begintake()
        local names = attnamelist(self)
        if names then
            local ret = setmetatable({ names = names, type = n.stat_localvar, pos = { left = tok.pos.left } }, mt)
            self:commit()
            tok = self:peek()
            if tok and tok.type == token.assignment then
                self:begintake()
                ret.values = explist(self)
                if ret.values then
                    self:commit()
                    ret.pos.right = ret.values.pos.right
                else
                    self:undo()
                    ret.pos.right = names.pos.right
                end
            else
                ret.pos.right = names.pos.right
            end
            return ret
        end
        self:undo()
    end
end
