local ret = {}
for i, name in ipairs(require 'qamar.tokenizer.token_names') do
    ret[name] = i
end
return ret
