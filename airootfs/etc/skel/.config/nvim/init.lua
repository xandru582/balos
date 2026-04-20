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
