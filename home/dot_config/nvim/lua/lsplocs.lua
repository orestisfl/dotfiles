-- LSP references/implementations that never block. The request runs in the
-- background, so a slow server (gopls on beats needs 10-30s after a cold start
-- or a build-tag change) neither freezes the editor nor times out. Results
-- open in fzf-lua only if the cursor is still where the lookup started; after
-- moving on they wait for M.open() instead of yanking you away.
local M = {}

local LABELS = {
  ["textDocument/references"] = "References",
  ["textDocument/implementation"] = "Implementations",
}
-- Fast lookups finish silently instead of flashing a progress message.
local PROGRESS_DELAY_MS = 300

local current -- in-flight lookup
local last -- latest finished lookup that had results

local function progress(lookup, status, msg)
  lookup.progress_shown = true
  vim.api.nvim_echo({ { msg } }, false, {
    id = "lsplocs.progress",
    kind = "progress",
    source = "lsplocs",
    title = lookup.label,
    status = status,
  })
end

-- Anything the user could have done since starting the lookup changes this.
local function position()
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(win)
  local row, col = unpack(vim.api.nvim_win_get_cursor(win))
  local mode = vim.api.nvim_get_mode().mode
  return ("%d:%d:%d:%d:%d:%s"):format(win, buf, row, col, vim.b[buf].changedtick, mode)
end

local function show(lookup)
  local items = lookup.items
  if #items == 1 then
    return vim.lsp.util.show_document(items[1].user_data, items[1].encoding, { focus = true })
  end
  -- Same options and entry format as fzf-lua's own LSP pickers, so preview and
  -- actions behave identically. These are fzf-lua internals, pinned by lazy-lock.
  local make_entry = require("fzf-lua.make_entry")
  local opts = require("fzf-lua.config").normalize_opts({
    cwd = vim.uv.cwd(),
    winopts = { title = (" %s "):format(lookup.label) },
  }, "lsp")
  if not opts then
    return
  end
  opts = require("fzf-lua.core").set_fzf_field_index(opts)
  local entries = {}
  for _, item in ipairs(items) do
    entries[#entries + 1] = make_entry.file(make_entry.lcol(item, opts), opts)
  end
  require("fzf-lua").fzf_exec(entries, opts)
end

local function finish(lookup, results)
  if current ~= lookup then
    return -- Superseded by a newer lookup.
  end
  current = nil
  local items, err = {}, nil
  for client_id, res in pairs(results) do
    local client = vim.lsp.get_client_by_id(client_id)
    if res.err then
      err = res.err.message
    elseif client and res.result then
      local locations = vim.islist(res.result) and res.result or { res.result }
      for _, item in ipairs(vim.lsp.util.locations_to_items(locations, client.offset_encoding)) do
        item.encoding = client.offset_encoding -- For jumping to a lone result.
        items[#items + 1] = item
      end
    end
  end
  if #items == 0 then
    return progress(lookup, err and "failed" or "success", err or "none found")
  end
  lookup.items = items
  last = lookup
  if lookup.open or position() == lookup.position then
    if lookup.progress_shown then
      progress(lookup, "success", ("%d found"):format(#items))
    end
    show(lookup)
  else
    progress(lookup, "success", ("%d found, gr' to open"):format(#items))
  end
end

--- Look up `method` at the cursor in the background.
---@param method string textDocument/references or textDocument/implementation
function M.find(method)
  local buf = vim.api.nvim_get_current_buf()
  if not next(vim.lsp.get_clients({ bufnr = buf, method = method })) then
    return vim.notify("No LSP client supports " .. method, vim.log.levels.WARN)
  end
  if current then
    current.cancel()
  end
  local lookup = { label = LABELS[method], position = position() }
  current = lookup
  local win = vim.api.nvim_get_current_win()
  lookup.cancel = vim.lsp.buf_request_all(buf, method, function(client)
    local params = vim.lsp.util.make_position_params(win, client.offset_encoding)
    params.context = { includeDeclaration = true } -- Only read by references.
    return params
  end, function(results)
    finish(lookup, results)
  end)
  vim.defer_fn(function()
    if current == lookup then
      progress(lookup, "running", "searching…")
    end
  end, PROGRESS_DELAY_MS)
end

--- Open the latest results; if a lookup is still running, open it when done.
function M.open()
  if current then
    current.open = true
    progress(current, "running", "searching…, opens when done")
  elseif last then
    show(last)
  else
    vim.notify("No LSP results yet", vim.log.levels.INFO)
  end
end

return M
