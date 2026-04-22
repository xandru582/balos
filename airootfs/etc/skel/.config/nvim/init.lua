-- BalOS Neovim config — hacker-minimal, LSP-ready, Matrix theme
-- ~/.config/nvim/init.lua

-- ═══ core options ═══════════════════════════════════════════════════
vim.g.mapleader = ' '
vim.g.maplocalleader = ','
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true
vim.opt.signcolumn = 'yes'
vim.opt.wrap = false
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.termguicolors = true
vim.opt.background = 'dark'
vim.opt.clipboard = 'unnamedplus'
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.smartindent = true
vim.opt.undofile = true
vim.opt.undodir = vim.fn.stdpath('data') .. '/undo'
vim.opt.swapfile = false
vim.opt.updatetime = 250
vim.opt.timeoutlen = 400
vim.opt.mouse = 'a'
vim.opt.completeopt = 'menu,menuone,noselect'
vim.opt.list = true
vim.opt.listchars = { tab = '→ ', trail = '·', nbsp = '␣' }

-- ═══ lazy.nvim bootstrap ════════════════════════════════════════════
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        'git', 'clone', '--filter=blob:none',
        'https://github.com/folke/lazy.nvim.git',
        '--branch=stable', lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

-- ═══ plugins ════════════════════════════════════════════════════════
require('lazy').setup({

    -- Matrix colorscheme (we'll build our own inline)
    { 'sainnhe/sonokai', priority = 1000 },

    -- Telescope fuzzy finder
    {
        'nvim-telescope/telescope.nvim',
        dependencies = { 'nvim-lua/plenary.nvim' },
        keys = {
            { '<leader>f', '<cmd>Telescope find_files<cr>', desc = 'Find file' },
            { '<leader>g', '<cmd>Telescope live_grep<cr>',  desc = 'Grep' },
            { '<leader>b', '<cmd>Telescope buffers<cr>',    desc = 'Buffers' },
            { '<leader>h', '<cmd>Telescope help_tags<cr>',  desc = 'Help' },
        },
    },

    -- Treesitter syntax
    {
        'nvim-treesitter/nvim-treesitter',
        build = ':TSUpdate',
        config = function()
            require('nvim-treesitter.configs').setup {
                ensure_installed = {
                    'bash', 'c', 'python', 'rust', 'go', 'lua', 'json', 'yaml',
                    'markdown', 'html', 'css', 'javascript', 'typescript',
                    'nix', 'toml', 'dockerfile', 'sql', 'ruby', 'php',
                },
                highlight = { enable = true },
                indent = { enable = true },
            }
        end,
    },

    -- LSP: mason + lspconfig
    { 'williamboman/mason.nvim', config = true },
    {
        'williamboman/mason-lspconfig.nvim',
        dependencies = { 'neovim/nvim-lspconfig' },
        config = function()
            require('mason-lspconfig').setup {
                ensure_installed = { 'bashls', 'pyright', 'rust_analyzer', 'gopls', 'lua_ls' },
            }
            local lsp = require('lspconfig')
            local on_attach = function(_, buf)
                local map = function(k, f) vim.keymap.set('n', k, f, { buffer = buf }) end
                map('gd', vim.lsp.buf.definition)
                map('gr', vim.lsp.buf.references)
                map('K', vim.lsp.buf.hover)
                map('<leader>rn', vim.lsp.buf.rename)
                map('<leader>ca', vim.lsp.buf.code_action)
            end
            for _, s in ipairs({ 'bashls', 'pyright', 'rust_analyzer', 'gopls', 'lua_ls' }) do
                lsp[s].setup { on_attach = on_attach }
            end
        end,
    },

    -- Completion
    {
        'hrsh7th/nvim-cmp',
        dependencies = {
            'hrsh7th/cmp-nvim-lsp',
            'hrsh7th/cmp-buffer',
            'hrsh7th/cmp-path',
            'L3MON4D3/LuaSnip',
            'saadparwaiz1/cmp_luasnip',
        },
        config = function()
            local cmp = require('cmp')
            cmp.setup {
                snippet = { expand = function(a) require('luasnip').lsp_expand(a.body) end },
                mapping = cmp.mapping.preset.insert {
                    ['<CR>']    = cmp.mapping.confirm { select = true },
                    ['<Tab>']   = cmp.mapping.select_next_item(),
                    ['<S-Tab>'] = cmp.mapping.select_prev_item(),
                    ['<C-Space>'] = cmp.mapping.complete(),
                },
                sources = {
                    { name = 'nvim_lsp' },
                    { name = 'luasnip' },
                    { name = 'buffer' },
                    { name = 'path' },
                },
            }
        end,
    },

    -- Git signs
    { 'lewis6991/gitsigns.nvim', config = true },

    -- File tree
    {
        'nvim-tree/nvim-tree.lua',
        keys = { { '<leader>e', '<cmd>NvimTreeToggle<cr>', desc = 'File tree' } },
        config = true,
    },

    -- Statusline
    {
        'nvim-lualine/lualine.nvim',
        config = function()
            require('lualine').setup {
                options = {
                    theme = 'sonokai',
                    globalstatus = true,
                    section_separators = '',
                    component_separators = '│',
                },
            }
        end,
    },

    -- Comment toggle
    { 'numToStr/Comment.nvim', config = true },

    -- Hex editor for binary/RE work
    { 'RaafatTurki/hex.nvim', config = true },

    -- Which-key helper
    { 'folke/which-key.nvim', config = true },
})

-- ═══ Matrix colorscheme override ════════════════════════════════════
vim.cmd.colorscheme('sonokai')
vim.cmd [[
    highlight Normal       guibg=#020604 guifg=#00ff88
    highlight NormalFloat  guibg=#020604 guifg=#00ff88
    highlight CursorLine   guibg=#0a0f0a
    highlight LineNr       guifg=#004020
    highlight CursorLineNr guifg=#00ff88 gui=bold
    highlight SignColumn   guibg=#020604
    highlight Visual       guibg=#003322
    highlight StatusLine   guibg=#020604 guifg=#00ff88
    highlight Comment      guifg=#006040 gui=italic
    highlight String       guifg=#80ffc0
    highlight Function     guifg=#00ff88 gui=bold
    highlight Keyword      guifg=#40ffa0
    highlight Type         guifg=#00d078
]]

-- ═══ keymaps ════════════════════════════════════════════════════════
local map = vim.keymap.set
map('n', '<leader>w', '<cmd>w<cr>', { desc = 'Save' })
map('n', '<leader>q', '<cmd>q<cr>', { desc = 'Quit' })
map('n', '<Esc>', '<cmd>nohlsearch<cr>')
map('n', '<C-h>', '<C-w>h'); map('n', '<C-j>', '<C-w>j')
map('n', '<C-k>', '<C-w>k'); map('n', '<C-l>', '<C-w>l')
map('v', '<', '<gv'); map('v', '>', '>gv')

-- Terminal toggle
map('n', '<leader>t', '<cmd>split | resize 12 | terminal<cr>', { desc = 'Terminal' })

-- ═══ BalAI integration ══════════════════════════════════════════════
-- Lightweight wrapper around the `balai` CLI. Works offline.
-- Commands:
--   :BalAI ask        ask a question (prompt)
--   :BalAI cmd        generate a shell command from intent
--   :BalAI explain    explain current buffer / selection
--   :BalAI fix        diagnose an error (current buffer / :messages)
-- Default bindings:
--   <leader>ae        explain buffer (normal) / explain selection (visual)
--   <leader>ac        :BalAI cmd (prompts for intent)
--   <leader>aa        :BalAI ask (prompts for question)
--   <leader>af        :BalAI fix (explain :messages)
local function balai_run(subcmd, stdin_text, on_done)
    local title = 'BalAI · ' .. subcmd
    vim.cmd('botright 12split | enew')
    vim.bo.buftype = 'nofile'
    vim.bo.bufhidden = 'wipe'
    vim.bo.swapfile = false
    vim.wo.wrap = true
    vim.api.nvim_buf_set_name(0, title)
    local buf = vim.api.nvim_get_current_buf()
    local function append(data)
        if not data then return end
        for _, line in ipairs(data) do
            vim.api.nvim_buf_set_lines(buf, -1, -1, false, { line })
        end
        vim.cmd('normal! G')
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '▸ balai ' .. subcmd, '' })
    local cmd
    if subcmd == 'explain' then
        cmd = { 'balai', 'explain' }
    elseif subcmd == 'fix' then
        cmd = { 'balai', 'fix' }
    elseif subcmd == 'ask' then
        cmd = { 'balai', stdin_text or '' }
        stdin_text = nil
    elseif subcmd == 'cmd' then
        cmd = { 'balai', 'cmd', stdin_text or '' }
        stdin_text = nil
    else
        vim.notify('balai: unknown subcmd ' .. subcmd, vim.log.levels.ERROR)
        return
    end
    local job = vim.fn.jobstart(cmd, {
        stdout_buffered = false,
        on_stdout = function(_, data) vim.schedule(function() append(data) end) end,
        on_stderr = function(_, data) vim.schedule(function() append(data) end) end,
        on_exit = function() if on_done then vim.schedule(on_done) end end,
    })
    if stdin_text and stdin_text ~= '' then
        vim.fn.chansend(job, stdin_text)
        vim.fn.chanclose(job, 'stdin')
    end
end

local function visual_selection()
    local s = vim.fn.getpos("'<"); local e = vim.fn.getpos("'>")
    local lines = vim.fn.getline(s[2], e[2])
    if #lines == 0 then return '' end
    lines[#lines] = string.sub(lines[#lines], 1, e[3])
    lines[1] = string.sub(lines[1], s[3])
    return table.concat(lines, '\n')
end

vim.api.nvim_create_user_command('BalAI', function(opts)
    local sub = opts.fargs[1] or 'ask'
    local rest = table.concat(vim.list_slice(opts.fargs, 2), ' ')
    if sub == 'explain' then
        local text
        if opts.range == 2 then
            text = visual_selection()
        else
            text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
        end
        balai_run('explain', text)
    elseif sub == 'fix' then
        balai_run('fix', rest ~= '' and rest or nil)
    elseif sub == 'cmd' then
        if rest == '' then rest = vim.fn.input('intent: ') end
        if rest ~= '' then balai_run('cmd', rest) end
    elseif sub == 'ask' or sub == 'q' then
        if rest == '' then rest = vim.fn.input('? ') end
        if rest ~= '' then balai_run('ask', rest) end
    else
        vim.notify('usage: :BalAI {ask|cmd|explain|fix} [...]', vim.log.levels.WARN)
    end
end, { nargs = '*', range = true, desc = 'BalAI offline assistant' })

map('n', '<leader>ae', '<cmd>BalAI explain<cr>',  { desc = 'BalAI: explain buffer' })
map('v', '<leader>ae', ':BalAI explain<cr>',       { desc = 'BalAI: explain selection' })
map('n', '<leader>ac', ':BalAI cmd<cr>',           { desc = 'BalAI: generate command' })
map('n', '<leader>aa', ':BalAI ask<cr>',           { desc = 'BalAI: ask' })
map('n', '<leader>af', ':BalAI fix<cr>',           { desc = 'BalAI: fix' })
