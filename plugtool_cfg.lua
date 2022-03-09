return {
    config = function()
        nnoremap('<leader>cr', require('qamar').run, 'silent', 'test run qamar')
    end,
}
