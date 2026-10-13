-- Keeps gopls' -tags flags in sync with the //go:build line of the current
-- file. gopls only auto-detects GOOS/GOARCH variants, never user-defined tags
-- (golang/go#65089), so files behind custom tags get no LSP support until the
-- matching -tags are set.
local M = {}

local active = {} -- currently applied tags, as a set
local auto = true -- false after :GoTags pins tags manually
local applied = "" -- comma-joined applied tags, to skip no-op pushes

-- GOOS/GOARCH/toolchain atoms. gopls covers these with its own build views;
-- passing them through -tags would be wrong.
local builtin = {}
for word in ([[
  aix android darwin dragonfly freebsd hurd illumos ios js linux nacl netbsd
  openbsd plan9 solaris wasip1 windows zos
  386 amd64 amd64p32 arm arm64 loong64 mips mipsle mips64 mips64le ppc64
  ppc64le riscv64 s390x sparc sparc64 wasm
  unix cgo gc gccgo race msan asan
]]):gmatch("%S+") do
  builtin[word] = true
end

local function is_builtin(atom)
  return builtin[atom] or atom:match("^go1%.") ~= nil or atom:match("^goexperiment%.") ~= nil
end

-- The //go:build expression, which must appear before the package clause.
local function constraint(buf)
  for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, 500, false)) do
    if line:match("^package%s") then
      return nil
    end
    local expr = line:match("^//go:build%s+(.+)")
    if expr then
      return expr
    end
  end
end

local function build_flags()
  return applied ~= "" and { "-tags=" .. applied } or {}
end

local function push(client)
  client.settings =
    vim.tbl_deep_extend("force", client.settings or {}, { gopls = { buildFlags = build_flags() } })
  client:notify("workspace/didChangeConfiguration", { settings = client.settings })
end

-- gopls rebuilds its views on didChangeConfiguration when settings actually
-- changed; the vim.lsp.config update covers clients started later.
local function apply()
  local tags = vim.tbl_keys(active)
  table.sort(tags)
  local joined = table.concat(tags, ",")
  if joined == applied then
    return
  end
  applied = joined
  vim.lsp.config("gopls", { settings = { gopls = { buildFlags = build_flags() } } })
  for _, client in ipairs(vim.lsp.get_clients({ name = "gopls" })) do
    if client.initialized then
      push(client)
    end
  end
  vim.notify("gopls build tags: " .. (joined ~= "" and joined or "(none)"))
end

-- Adjusts the active set so the buffer's constraint is satisfied: atoms used
-- positively are turned on, atoms only used negated are turned off. Atoms
-- appearing with both polarities (e.g. an xor of two tags) are left alone.
function M.detect(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if not auto or not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  local expr = constraint(buf)
  if not expr then
    return
  end
  local pos, neg = {}, {}
  for at, atom in expr:gmatch("()([%w_.]+)") do
    if not is_builtin(atom) then
      if expr:sub(at - 1, at - 1) == "!" then
        neg[atom] = true
      else
        pos[atom] = true
      end
    end
  end
  local changed = false
  for atom in pairs(pos) do
    if not neg[atom] and not active[atom] then
      active[atom], changed = true, true
    end
  end
  for atom in pairs(neg) do
    if not pos[atom] and active[atom] then
      active[atom], changed = nil, true
    end
  end
  if changed then
    apply()
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup("gotags", {})
  local timer = assert(vim.uv.new_timer())

  -- Debounced: cycling through mixed-tag files (e.g. via quickfix) would
  -- otherwise trigger a full gopls workspace reload per file.
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    pattern = "*.go",
    callback = function(args)
      timer:start(300, 0, vim.schedule_wrap(function()
        if vim.api.nvim_get_current_buf() == args.buf then
          M.detect(args.buf)
        end
      end))
    end,
  })
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = "*.go",
    callback = function(args)
      M.detect(args.buf)
    end,
  })
  -- A client that started while tags changed can hold stale settings, and the
  -- first Go file is opened before gopls finishes initializing.
  vim.api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if not client or client.name ~= "gopls" then
        return
      end
      M.detect(args.buf)
      local flags = vim.tbl_get(client.settings or {}, "gopls", "buildFlags")
      if (flags and flags[1]) ~= build_flags()[1] then
        push(client)
      end
    end,
  })

  vim.api.nvim_create_user_command("GoTags", function(cmd)
    if cmd.args == "" then
      vim.notify(
        ("gopls build tags: %s [%s]"):format(
          applied ~= "" and applied or "(none)",
          auto and "auto" or "pinned"
        )
      )
    elseif cmd.args == "auto" then
      auto = true
      active = {}
      M.detect()
      apply()
    else
      auto = false
      active = {}
      if cmd.args ~= "none" then
        for tag in cmd.args:gmatch("[^,%s]+") do
          active[tag] = true
        end
      end
      apply()
    end
  end, {
    nargs = "?",
    complete = function()
      return { "auto", "none" }
    end,
    desc = "Show, pin (tag1,tag2), clear (none), or auto-detect (auto) gopls build tags",
  })
end

return M
