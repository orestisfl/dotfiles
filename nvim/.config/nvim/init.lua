-- Leaders (must be set before lazy.nvim)
vim.g.mapleader = " "
vim.g.maplocalleader = ","

-- Disable unused providers
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_node_provider = 0

-- Options
vim.opt.clipboard:append("unnamedplus") -- Use system clipboard
vim.opt.number = true
vim.opt.mouse:append("a")
vim.opt.inccommand = "nosplit" -- Live preview for :s substitutions
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.scrolloff = 10 -- Keep 10 lines visible around cursor
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.background = "dark"
vim.opt.foldmethod = "expr" -- Use treesitter for folding
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()" -- Fold on semantic blocks (functions, classes, etc.)
vim.opt.foldlevelstart = 99 -- Start with all folds open
vim.opt.completeopt = { "menu", "menuone", "noselect" }
vim.opt.undofile = true -- Persist undo history across sessions

-- Keymaps
vim.keymap.set("n", "<Leader>w", "<cmd>w<CR>")
vim.keymap.set("n", "<CR>", "<cmd>nohlsearch<CR><CR>")
vim.keymap.set("n", "<Leader>x", vim.diagnostic.setloclist, { desc = "Diagnostics to loclist" })
vim.keymap.set("n", "<Leader>q", function()
  local bufs = vim.fn.getbufinfo({ buflisted = 1 })
  if #bufs > 1 then
    vim.cmd("bprevious | bdelete #")
  else
    vim.cmd("bdelete")
  end
end, { desc = "Close buffer" })

-- Autocmds
-- Enable treesitter highlighting for languages with locally-installed parsers
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "go" },
  callback = function() pcall(vim.treesitter.start) end,
})
-- Restore cursor to last known position when reopening a file
vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(0) then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Plugins
require("lazy").setup({
  rocks = { enabled = false, hererocks = false }, -- No plugins need luarocks
  {
    "neovim/nvim-lspconfig", -- Default LSP server configurations (servers installed via system packages)
    config = function()
      -- Neovim 0.11+ global defaults: grn=rename, gra=code action,
      -- grr=references, gri=implementation, grt=type definition,
      -- gO=document symbols, <C-S>=signature help, [d/]d=diagnostics,
      -- <C-W>d=diagnostic float
      vim.lsp.config("*", {
        on_attach = function(client, bufnr)
          vim.keymap.set("n", "gd", vim.lsp.buf.definition, { buffer = bufnr, desc = "Go to definition" })
          vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { buffer = bufnr, desc = "Go to declaration" })
          vim.lsp.completion.enable(true, client.id, bufnr, { autotrigger = true })
        end,
      })
      vim.lsp.inlay_hint.enable(true)
      vim.lsp.enable({ "clangd", "pyright", "gopls" })
    end,
  },

  {
    "ellisonleao/gruvbox.nvim", -- Treesitter-aware gruvbox colorscheme
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("gruvbox")
    end,
  },

  {
    "kylechui/nvim-surround", -- Add/change/delete surrounding pairs (cs, ds, ys, s in visual)
    init = function()
      vim.g.nvim_surround_no_visual_mappings = true
    end,
    config = function()
      require("nvim-surround").setup()
      vim.keymap.set("x", "s", "<Plug>(nvim-surround-visual)")
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter-context", -- Show current function/class at top of buffer
    opts = {},
  },

  { "tpope/vim-fugitive" }, -- Git commands (:Git, :GBrowse, etc.)
  { "tpope/vim-rhubarb" }, -- GitHub handler for :GBrowse

  {
    "ibhagwan/fzf-lua", -- Fuzzy finder for files, buffers, grep
    config = function()
      local fzf = require("fzf-lua")
      fzf.setup({
        fzf_opts = {
          ["--bind"] = "alt-a:select-all,alt-d:deselect-all",
        },
        grep = {
          rg_opts = "--column --line-number --no-heading --color=always --smart-case --hidden --glob '!.git'",
        },
      })
      vim.keymap.set("n", "<Leader>f", fzf.files, { desc = "Find files" })
      vim.keymap.set("n", "<Leader>b", fzf.buffers, { desc = "Find buffers" })
      vim.keymap.set("n", "<Leader>rg", fzf.live_grep, { desc = "Live grep" })
    end,
  },
})

-- Add ~/.local/share/nvim to runtimepath for locally-compiled treesitter parsers/queries
vim.opt.rtp:prepend(vim.fn.stdpath("data"))
