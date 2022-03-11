local token, precedence = require 'qamar.tokenizer.types', require 'qamar.parser.precedence'

return {
    infix = {
        [token.kw_or] = { precedence = precedence.lor, parse = require 'qamar.parser.parselets.infix' },
        [token.kw_and] = { precedence = precedence.land, parse = require 'qamar.parser.parselets.infix' },
        [token.lt] = { precedence = precedence.comparison, parse = require 'qamar.parser.parselets.infix' },
        [token.gt] = { precedence = precedence.comparison, parse = require 'qamar.parser.parselets.infix' },
        [token.leq] = { precedence = precedence.comparison, parse = require 'qamar.parser.parselets.infix' },
        [token.geq] = { precedence = precedence.comparison, parse = require 'qamar.parser.parselets.infix' },
        [token.neq] = { precedence = precedence.comparison, parse = require 'qamar.parser.parselets.infix' },
        [token.eq] = { precedence = precedence.comparison, parse = require 'qamar.parser.parselets.infix' },
        [token.bitor] = { precedence = precedence.bor, parse = require 'qamar.parser.parselets.infix' },
        [token.bitnot] = { precedence = precedence.bxor, parse = require 'qamar.parser.parselets.infix' },
        [token.bitand] = { precedence = precedence.band, parse = require 'qamar.parser.parselets.infix' },
        [token.lshift] = { precedence = precedence.shift, parse = require 'qamar.parser.parselets.infix' },
        [token.rshift] = { precedence = precedence.shift, parse = require 'qamar.parser.parselets.infix' },
        [token.concat] = { precedence = precedence.concat, parse = require 'qamar.parser.parselets.infix', right_associative = true },
        [token.add] = { precedence = precedence.add, parse = require 'qamar.parser.parselets.infix' },
        [token.sub] = { precedence = precedence.add, parse = require 'qamar.parser.parselets.infix' },
        [token.mul] = { precedence = precedence.mul, parse = require 'qamar.parser.parselets.infix' },
        [token.div] = { precedence = precedence.mul, parse = require 'qamar.parser.parselets.infix' },
        [token.fdiv] = { precedence = precedence.mul, parse = require 'qamar.parser.parselets.infix' },
        [token.mod] = { precedence = precedence.mul, parse = require 'qamar.parser.parselets.infix' },
        [token.exp] = { precedence = precedence.exp, parse = require 'qamar.parser.parselets.infix', right_associative = true },
    },
    prefix = {
        [token.kw_not] = { precedence = precedence.unary, parse = require 'qamar.parser.parselets.prefix' },
        [token.len] = { precedence = precedence.unary, parse = require 'qamar.parser.parselets.prefix' },
        [token.sub] = { precedence = precedence.unary, parse = require 'qamar.parser.parselets.prefix' },
        [token.bitnot] = { precedence = precedence.unary, parse = require 'qamar.parser.parselets.prefix' },
        [token.lparen] = { precedence = precedence.atom, parse = require 'qamar.parser.parselets.subexpression' },
        [token.name] = { precedence = precedence.atom, parse = require 'qamar.parser.parselets.atom' },
        [token.number] = { precedence = precedence.atom, parse = require 'qamar.parser.parselets.atom' },
    },
}
