-- Reopen the current buffers in other worktrees of the same repository,
-- one new terminal window per worktree.
local M = {}

local function git(cwd, ...)
  local res = vim.system({ "git", "-C", cwd, ... }, { text = true }):wait()
  if res.code ~= 0 then
    return nil, vim.trim(res.stderr ~= "" and res.stderr or res.stdout)
  end
  return vim.trim(res.stdout)
end

local function short(path)
  return vim.fn.fnamemodify(path, ":~")
end

-- Compact "3h"/"5d" age, narrow enough for the column to stay aligned.
local function age(stamp)
  if stamp == 0 then
    return "-" -- Branch without commits.
  end
  local secs = os.time() - stamp
  for _, unit in ipairs({ { 60, "s" }, { 60, "m" }, { 24, "h" }, { 7, "d" }, { 52, "w" } }) do
    if secs < unit[1] then
      return math.floor(secs) .. unit[2]
    end
    secs = secs / unit[1]
  end
  return math.floor(secs) .. "y"
end

-- Root of the worktree we are in, or nil after reporting why there is none.
local function current_root()
  local root, err = git(vim.uv.cwd(), "rev-parse", "--show-toplevel")
  if not root then
    vim.notify("Not in a git worktree: " .. err, vim.log.levels.WARN)
    return nil
  end
  return vim.fs.normalize(root)
end

-- `git worktree list --porcelain` prints a record per worktree: its path, then
-- its HEAD and either the checked out branch or `detached`/`bare`.
local function list_worktrees()
  local out, err = git(vim.uv.cwd(), "worktree", "list", "--porcelain")
  if not out then
    return nil, err
  end
  local worktrees, cur = {}, nil
  for line in vim.gsplit(out, "\n") do
    local path = line:match("^worktree (.+)$")
    local head = line:match("^HEAD (%x+)$")
    local branch = line:match("^branch (.+)$")
    if path then
      cur = { path = vim.fs.normalize(path) }
      worktrees[#worktrees + 1] = cur
    elseif head then
      cur.label = head:sub(1, 8) -- Detached, unless a branch line follows.
    elseif branch then
      cur.label = branch:gsub("^refs/heads/", "")
    elseif line == "bare" then
      cur.bare = true -- No checkout, so nothing to open there.
    end
  end
  return worktrees
end

-- Listed file buffers, relative to `root`. Buffers outside the worktree have no
-- counterpart to open; a second nvim on them would only fight over the swapfile.
local function buffer_paths(root)
  local paths = {}
  for _, buf in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
    local name = buf.name ~= "" and vim.fs.normalize(buf.name)
    if name and vim.bo[buf.bufnr].buftype == "" and vim.startswith(name, root .. "/") then
      paths[#paths + 1] = name:sub(#root + 2)
    end
  end
  return paths
end

--- Open this worktree's buffers in another checkout of the same repository.
---@param path string Root of the worktree to open.
function M.open(path)
  local root = current_root()
  if not root then
    return
  end
  local argv, missing = { "nvim" }, {}
  for _, file in ipairs(buffer_paths(root)) do
    table.insert(vim.uv.fs_stat(path .. "/" .. file) and argv or missing, file)
  end
  if #missing > 0 then
    -- Worktrees sit at different commits, so a file existing in only one of
    -- them is expected rather than an error.
    vim.notify(("%s: skipped %s"):format(short(path), table.concat(missing, ", ")))
  end
  -- --dir starts the terminal, and so nvim, in the worktree that the arguments
  -- above are relative to.
  vim.system(
    vim.list_extend({ "xdg-terminal-exec", "--dir=" .. path, "--" }, argv),
    { detach = true, text = true },
    vim.schedule_wrap(function(res)
      if res.code ~= 0 then
        local msg = vim.trim(res.stderr or "")
        vim.notify(("xdg-terminal-exec exited %d: %s"):format(res.code, msg), vim.log.levels.ERROR)
      end
    end)
  )
end

--- Pick worktrees other than the current one, most recent commit first, and
--- open each in its own terminal.
function M.pick()
  local root = current_root()
  if not root then
    return
  end
  local worktrees, err = list_worktrees()
  if not worktrees then
    return vim.notify(err, vim.log.levels.ERROR)
  end
  local others = {}
  for _, wt in ipairs(worktrees) do
    if not wt.bare and wt.path ~= root then
      -- Per worktree rather than one batch call over the commits: `git show`
      -- collapses duplicates, and worktrees often share a commit.
      wt.time = tonumber(git(wt.path, "log", "-1", "--format=%ct")) or 0
      others[#others + 1] = wt
    end
  end
  if #others == 0 then
    return vim.notify("No other worktrees", vim.log.levels.WARN)
  end
  -- Name breaks ties so worktrees branched off the same commit keep an order.
  table.sort(others, function(a, b)
    if a.time ~= b.time then
      return a.time > b.time
    end
    return a.label < b.label
  end)
  local entries, paths = {}, {}
  for _, wt in ipairs(others) do
    local entry = ("%-20s %-4s %s"):format(wt.label, age(wt.time), short(wt.path))
    entries[#entries + 1] = entry
    paths[entry] = wt.path
  end
  require("fzf-lua").fzf_exec(entries, {
    prompt = "Worktrees> ",
    fzf_opts = { ["--multi"] = true },
    actions = {
      ["default"] = function(selected)
        for _, entry in ipairs(selected or {}) do
          M.open(paths[entry])
        end
      end,
    },
  })
end

return M
