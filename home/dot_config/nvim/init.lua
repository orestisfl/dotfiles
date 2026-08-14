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
  local buf = vim.api.nvim_get_current_buf()
  local bufs = vim.fn.getbufinfo({ buflisted = 1 })
  if #bufs > 1 then
    vim.cmd("bprevious")
  end
  if vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_delete(buf, {})
  end
end, { desc = "Close buffer" })
vim.keymap.set("n", "<C-w>]", "<cmd>vertical wincmd ]<CR>", { desc = "Definition in vsplit" })

-- Autocmds
-- Enable treesitter highlighting
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "c", "go", "gomod", "gosum", "gowork", "lua", "python", "rust" },
  callback = function() pcall(vim.treesitter.start) end,
})
-- Pick up files changed on disk without :e
vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold" }, {
  callback = function(ev)
    if vim.fn.getcmdwintype() == "" then
      vim.cmd.checktime({ args = { tostring(ev.buf) } })
    end
  end,
})
-- Restore cursor to last known position when reopening a file
vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function(ev)
    local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
    local filetype = vim.bo[ev.buf].filetype
    if
      mark[1] >= 1
      and mark[1] <= vim.api.nvim_buf_line_count(ev.buf)
      and not filetype:find("commit", 1, true)
      and filetype ~= "xxd"
      and filetype ~= "gitrebase"
      and not vim.wo.diff
    then
      vim.cmd.normal({ args = { 'g`"' }, bang = true })
    end
  end,
})

-- Go tests
local gotest = require("gotest")
vim.api.nvim_create_autocmd("FileType", {
  pattern = "go",
  callback = function(ev)
    -- Lowercase runs, uppercase offers the command for editing first
    for key, scope in pairs({ n = "nearest", f = "file", p = "package" }) do
      vim.keymap.set("n", "<Leader>t" .. key, function() gotest.test(scope) end, {
        buffer = ev.buf,
        desc = "Test " .. scope,
      })
      vim.keymap.set("n", "<Leader>t" .. key:upper(), function() gotest.test(scope, true) end, {
        buffer = ev.buf,
        desc = "Test " .. scope .. ", edit command",
      })
    end
  end,
})
-- Reruns work globally
vim.keymap.set("n", "<Leader>tt", gotest.rerun, { desc = "Rerun last test" })
vim.keymap.set("n", "<Leader>tx", gotest.history, { desc = "Test command history" })

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
    "neovim/nvim-lspconfig", -- Default LSP server configurations
    config = function()
      vim.lsp.config("*", {
        on_attach = function(client, bufnr)
          vim.keymap.set("n", "gd", vim.lsp.buf.definition, { buffer = bufnr, desc = "Go to definition" })
          vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { buffer = bufnr, desc = "Go to declaration" })
          vim.lsp.completion.enable(true, client.id, bufnr, { autotrigger = true })
        end,
      })
      vim.lsp.config("gopls", {
        settings = { gopls = { buildFlags = { "-tags=" .. gotest.build_tags } } },
      })
      vim.lsp.inlay_hint.enable(true)
      vim.lsp.enable({ "clangd", "pyright", "gopls", "rust_analyzer" })
    end,
  },

  {
    "ellisonleao/gruvbox.nvim", -- Treesitter-aware gruvbox colorscheme
    priority = 1000,
    config = function()
      require("gruvbox").setup({
        -- Stock diff backgrounds are too bright
        overrides = {
          DiffAdd = { bg = "#34381b" },
          DiffDelete = { bg = "#402120" },
          DiffChange = { bg = "#0e363e" },
          DiffText = { bg = "#2c5d70" },
        },
      })
      vim.cmd.colorscheme("gruvbox")
    end,
  },

  {
    "folke/which-key.nvim", -- Popup listing possible continuations after a prefix key
    event = "VeryLazy",
    opts = {
      preset = "helix",
      delay = 300,
    },
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
    "nvim-treesitter/nvim-treesitter", -- Parser/query installer
    branch = "main",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter").install({ "go", "gomod", "gosum", "gowork", "rust", "python", "c" })
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter-context", -- Show current function/class at top of buffer
    opts = {},
  },

  {
    "esmuellert/codediff.nvim", -- Code diff with character-level highlighting
    cmd = "CodeDiff",
    keys = {
      { "<Leader>gs", "<cmd>CodeDiff<CR>", desc = "Diff changed files" },
      { "<Leader>gd", "<cmd>CodeDiff file HEAD<CR>", desc = "Diff file vs HEAD" },
      { "<Leader>gh", "<cmd>CodeDiff history<CR>", desc = "File history" },
      {
        "<Leader>gr",
        function()
          -- PR-style review: merge-base of the default branch vs current branch
          vim.system({ "git", "upstream-ref" }, { text = true }, vim.schedule_wrap(function(result)
            local ref = vim.trim(result.stdout or "")
            if result.code ~= 0 or ref == "" then
              return vim.notify("git upstream-ref failed", vim.log.levels.WARN)
            end
            vim.cmd.CodeDiff(ref .. "...")
          end))
        end,
        desc = "Review branch vs default branch",
      },
    },
    opts = {},
  },

  {
    "lewis6991/gitsigns.nvim", -- Hunk signs, navigation, and blame; staging stays in the CLI
    opts = {
      current_line_blame = true, -- Inline blame at end of line
      current_line_blame_opts = { delay = 0 },
      on_attach = function(bufnr)
        local gs = require("gitsigns")
        local function map(mode, l, r, desc)
          vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
        end
        local function nav(dir)
          return function()
            if vim.wo.diff then
              vim.cmd.normal({ dir == "next" and "]c" or "[c", bang = true })
            else
              gs.nav_hunk(dir)
            end
          end
        end
        map("n", "]c", nav("next"), "Next hunk")
        map("n", "[c", nav("prev"), "Previous hunk")
        map("n", "<Leader>gp", gs.preview_hunk, "Preview hunk")
        map("n", "<Leader>gb", function() gs.blame_line({ full = true }) end, "Blame line")
        map("n", "<Leader>gB", gs.blame, "Blame buffer")
      end,
    },
  },

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
      -- LSP pickers: multi-result navigation with preview, jump directly when unique
      vim.keymap.set("n", "grr", fzf.lsp_references, { desc = "References" })
      vim.keymap.set("n", "gri", fzf.lsp_implementations, { desc = "Implementations" })
      vim.keymap.set("n", "gO", fzf.lsp_document_symbols, { desc = "Document symbols" })
      vim.keymap.set("n", "<Leader>s", fzf.lsp_live_workspace_symbols, { desc = "Workspace symbols" })
      -- Git pickers
      vim.keymap.set("n", "<Leader>gl", fzf.git_bcommits, { desc = "File commit log" })
      vim.keymap.set("n", "<Leader>gL", fzf.git_commits, { desc = "Repo commit log" })
      vim.keymap.set("n", "<Leader>ch", fzf.command_history, { desc = "Command history" })
      vim.keymap.set("n", "<Leader>km", fzf.keymaps, { desc = "Search keymaps" })
      vim.keymap.set("n", "<Leader>'", fzf.resume, { desc = "Resume last picker" })
      vim.keymap.set("n", "<Leader>/", fzf.blines, { desc = "Fuzzy lines in buffer" })
      vim.keymap.set("n", "<Leader>?", fzf.lines, { desc = "Fuzzy lines in all buffers" })
      vim.keymap.set("n", "<Leader>z", fzf.zoxide, { desc = "Change cwd via zoxide" })
    end,
  },

  {
    "nvim-mini/mini.files", -- Navigate and manipulate file system
    keys = {
      {
        "<Leader>e",
        function() require("mini.files").open(vim.api.nvim_buf_get_name(0)) end,
        desc = "Explorer at current file",
      },
      {
        "<Leader>E",
        function() require("mini.files").open(vim.uv.cwd(), false) end,
        desc = "Explorer at cwd",
      },
    },
    opts = {
      options = { permanent_delete = false }, -- Uses stdpath("data")/mini.files/trash
      windows = { preview = true, width_focus = 35, width_preview = 60 },
    },
  },

  {
    "orestisfl/margin.nvim",
    lazy = false,
    opts = {},
    keys = {
      { "<Leader>mc", "<Plug>(margin-comment)", mode = { "n", "x" }, desc = "Margin comment" },
      { "<Leader>me", "<Plug>(margin-edit)", desc = "Margin edit" },
      { "<Leader>md", "<Plug>(margin-delete)", desc = "Margin delete" },
      { "<Leader>ml", "<Plug>(margin-list)", desc = "Margin list" },
      { "<Leader>mx", "<Plug>(margin-export)", desc = "Margin export" },
      { "]m", "<Plug>(margin-next)", desc = "Next margin comment" },
      { "[m", "<Plug>(margin-prev)", desc = "Prev margin comment" },
    },
  },
})
