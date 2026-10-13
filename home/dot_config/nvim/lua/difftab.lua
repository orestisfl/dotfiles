-- Open the working file behind a CodeDiff pane in another tab, at the cursor
-- location, leaving the diff tab as it is. Reads codediff internals (session
-- table, compact line mapping); its README marks those unsupported.
local M = {}

local api = vim.api
local lifecycle = require("codediff.ui.lifecycle")

local function is_file(buf)
  return buf and api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == ""
end

-- Working-tree path and cursor for the current pane, or nil and why not.
local function location(sess)
  local buf = api.nvim_get_current_buf()
  local side = buf == sess.original_bufnr and "original" or buf == sess.modified_bufnr and "modified" or nil
  if not side then
    return nil, "Not on a CodeDiff diff pane"
  end
  local cursor = api.nvim_win_get_cursor(0)
  if is_file(buf) then
    return api.nvim_buf_get_name(buf), cursor
  end

  -- Revision pane facing the working file: follow the diff to the matching line
  local other = side == "original" and "modified" or "original"
  local other_buf = sess[other .. "_bufnr"]
  local changes = sess.stored_diff_result and sess.stored_diff_result.changes
  if changes and is_file(other_buf) then
    local lnum = require("codediff.ui.view.compact").compute_corresponding_lnum(changes, side, other, cursor[1])
    return api.nvim_buf_get_name(other_buf), { lnum, cursor[2] }
  end

  -- Both sides are revisions: same line of the working file, best effort
  local path = sess[side] and sess[side].absolute or ""
  if path == "" or not vim.uv.fs_stat(path) then
    return nil, "File not in the working tree"
  end
  return path, cursor
end

-- Next tab after `cur`, wrapping, that is not a diff itself.
local function next_tab(cur)
  local tabs = api.nvim_list_tabpages()
  local i = vim.fn.index(tabs, cur)
  for step = 1, #tabs - 1 do
    local tab = tabs[(i + step) % #tabs + 1]
    if not lifecycle.get_session(tab) then
      return tab
    end
  end
end

function M.open()
  local cur = api.nvim_get_current_tabpage()
  local sess = lifecycle.get_session(cur)
  if not sess then
    return vim.notify("Not in a CodeDiff tab", vim.log.levels.WARN)
  end
  local path, cursor = location(sess)
  if not path then
    return vim.notify(cursor, vim.log.levels.WARN)
  end

  local buf = vim.fn.bufadd(path)
  vim.bo[buf].buflisted = true
  local tab = next_tab(cur)
  if tab then
    api.nvim_set_current_tabpage(tab)
    api.nvim_win_set_buf(0, buf)
  else
    vim.cmd("tab sbuffer " .. buf)
  end
  cursor[1] = math.min(cursor[1], api.nvim_buf_line_count(buf))
  api.nvim_win_set_cursor(0, cursor)
end

return M
