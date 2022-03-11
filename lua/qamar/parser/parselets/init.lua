local precedences = require 'qamar.parser.precedence'
local token_types = require 'qamar.tokenizer.types'

local parselets = {
    infix = {
        [token_types.kw_or] = { precedence = precedences.lor, right_associative = false, parse = require 'qamar.parser.parselets.infix' },
        [token_types.kw_and] = { precedence = precedences.land, right_associative = false, parse = require 'qamar.parser.parselets.infix' },
        [token_types.lt] = { precedence = precedences.comparison, right_associative = false, parse = require 'qamar.parser.parselets.infix' },
        [token_types.gt] = { precedence = precedences.comparison, right_associative = false, parse = require 'qamar.parser.parselets.infix' },
        [token_types.leq] = { precedence = precedences.comparison, right_associative = false, parse = require 'qamar.parser.parselets.infix' },
        [token_types.geq] = { precedence = precedences.comparison, right_associative = false, parse = require 'qamar.parser.parselets.infix' },
        [token_types.neq] = { precedence = precedences.comparison, right_associative = false, parse = require 'qamar.parser.parselets.infix' },
        [token_types.eq] = { precedence = precedences.comparison, right_associative = false, parse = require 'qamar.parser.parselets.infix' },
        [token_types.bitor] = { precedence = precedences.bor, right_associative = false, parse = require 'qamar.parser.parselets.infix' },
        [token_types.bitnot] = { precedence = precedences.bxor, right_associative = false, parse = require 'qamar.parser.parselets.infix' },
        [token_types.bitand] = { precedence = precedences.band, right_associative = false, parse = require 'qamar.parser.parselets.infix' },
        [token_types.lshift] = { precedence = precedences.shift, right_associative = false, parse = require 'qamar.parser.parselets.infix' },
        [token_types.rshift] = { precedence = precedences.shift, right_associative = false, parse = require 'qamar.parser.parselets.infix' },
        [token_types.concat] = { precedence = precedences.concat, right_associative = true, parse = require 'qamar.parser.parselets.infix' },
        [token_types.add] = { precedence = precedences.add, right_associative = false, parse = require 'qamar.parser.parselets.infix' },
        [token_types.sub] = { precedence = precedences.add, right_associative = false, parse = require 'qamar.parser.parselets.infix' },
        [token_types.mul] = { precedence = precedences.mul, right_associative = false, parse = require 'qamar.parser.parselets.infix' },
        [token_types.div] = { precedence = precedences.mul, right_associative = false, parse = require 'qamar.parser.parselets.infix' },
        [token_types.fdiv] = { precedence = precedences.mul, right_associative = false, parse = require 'qamar.parser.parselets.infix' },
        [token_types.mod] = { precedence = precedences.mul, right_associative = false, parse = require 'qamar.parser.parselets.infix' },
        [token_types.exp] = { precedence = precedences.exp, right_associative = true, parse = require 'qamar.parser.parselets.infix' },
    },
    prefix = {
        [token_types.kw_not] = { precedence = precedences.unary, right_associative = false, parse = require 'qamar.parser.parselets.prefix' },
        [token_types.len] = { precedence = precedences.unary, right_associative = false, parse = require 'qamar.parser.parselets.prefix' },
        [token_types.sub] = { precedence = precedences.unary, right_associative = false, parse = require 'qamar.parser.parselets.prefix' },
        [token_types.bitnot] = { precedence = precedences.unary, right_associative = false, parse = require 'qamar.parser.parselets.prefix' },
        [token_types.lparen] = { precedence = precedences.atom, right_associative = false, parse = require 'qamar.parser.parselets.subexpression' },
        [token_types.name] = { precedence = precedences.atom, right_associative = false, parse = require 'qamar.parser.parselets.atom' },
        [token_types.number] = { precedence = precedences.atom, right_associative = false, parse = require 'qamar.parser.parselets.atom' },
    },
}
return parselets
