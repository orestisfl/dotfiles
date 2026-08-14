-- Runs `go test` with output in a reused terminal split.
local M = {}

M.build_tags = "integration"

local query, out_win, last_run
local history = {}
local ns = vim.api.nvim_create_namespace("gotest")

-- Find Go test functions in document order.
local function tests_in_buf(bufnr)
  local parser = assert(vim.treesitter.get_parser(bufnr, "go"))
  query = query
    or vim.treesitter.query.parse(
      "go",
      [[(function_declaration
           name: (identifier) @name
           (#match? @name "^(Test|Benchmark|Fuzz|Example)([^a-z]|$)"))]]
    )
  local tests = {}
  for _, node in query:iter_captures(parser:parse()[1]:root(), bufnr) do
    local row = node:range()
    tests[#tests + 1] = { name = vim.treesitter.get_node_text(node, bufnr), row = row }
  end
  return tests
end

-- Quote arguments that the shell can parse differently.
local function shell_join(argv)
  local parts = {}
  for i, arg in ipairs(argv) do
    parts[i] = arg:match("^[%w@%%_+=:,./-]+$") and arg or vim.fn.shellescape(arg)
  end
  return table.concat(parts, " ")
end

-- Move a repeated command to the end of the history.
local function record(cmd, cwd)
  local text = type(cmd) == "table" and shell_join(cmd) or cmd
  for i, entry in ipairs(history) do
    if entry.cmd == text and entry.cwd == cwd then
      table.remove(history, i)
      break
    end
  end
  history[#history + 1] = { cmd = text, cwd = cwd }
end

local function run(cmd, cwd)
  last_run = { cmd = cmd, cwd = cwd }
  record(cmd, cwd)
  -- Reuse one split and discard its old output buffer.
  if out_win and vim.api.nvim_win_is_valid(out_win) then
    vim.api.nvim_set_current_win(out_win)
    vim.cmd("enew")
  else
    vim.cmd("botright 15split | enew")
    out_win = vim.api.nvim_get_current_win()
  end
  vim.bo.bufhidden = "wipe"
  vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = true, desc = "Close test output" })
  vim.fn.jobstart(cmd, { term = true, cwd = cwd })
end

local function build_cmd(pattern, bench)
  local cmd = { "go", "test", "-v", "-tags=" .. M.build_tags }
  if bench then
    -- `-run "^$"` skips normal tests. `-bench` selects the benchmark.
    vim.list_extend(cmd, { "-run", "^$", "-bench", pattern })
  elseif pattern then
    vim.list_extend(cmd, { "-run", pattern })
  end
  cmd[#cmd + 1] = "."
  return cmd
end

---@param scope "nearest"|"file"|"package"
---@param edit? boolean
function M.test(scope, edit)
  local bufnr = vim.api.nvim_get_current_buf()
  local dir = vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr))
  local cmd
  if scope == "package" then
    cmd = build_cmd(nil, false)
  elseif scope == "file" then
    local names = {}
    for _, t in ipairs(tests_in_buf(bufnr)) do
      if not t.name:match("^Benchmark") then
        names[#names + 1] = t.name
      end
    end
    if #names == 0 then
      return vim.notify("No tests in this file", vim.log.levels.WARN)
    end
    cmd = build_cmd("^(" .. table.concat(names, "|") .. ")$", false)
  else
    local row = vim.api.nvim_win_get_cursor(0)[1] - 1
    local nearest
    for _, t in ipairs(tests_in_buf(bufnr)) do
      if t.row <= row then
        nearest = t
      end
    end
    if not nearest then
      return vim.notify("No test at or above the cursor", vim.log.levels.WARN)
    end
    cmd = build_cmd("^" .. nearest.name .. "$", nearest.name:match("^Benchmark") ~= nil)
  end
  if not edit then
    return run(cmd, dir)
  end
  vim.ui.input({ prompt = "go test: ", default = shell_join(cmd) }, function(edited)
    if edited and edited:match("%S") then
      run(edited, dir)
    end
  end)
end

-- Show one command per line. <CR> runs the selected command.
-- An edited command creates a new history entry.
function M.history()
  if #history == 0 then
    return vim.notify("No test runs yet", vim.log.levels.WARN)
  end
  local lines = {}
  for i, entry in ipairs(history) do
    lines[i] = entry.cmd
  end
  vim.cmd("botright " .. math.max(3, math.min(#lines, 15)) .. "split | enew")
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "sh" -- Use shell highlighting for quoted `-run` patterns.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Link each command to its cwd with an extmark that follows edits.
  -- This distinguishes identical commands from different packages and removes stale links.
  local cwds = {}
  for i, entry in ipairs(history) do
    local id = vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
      end_row = i - 1,
      end_col = #entry.cmd,
      invalidate = true,
      undo_restore = false,
      virt_text = { { vim.fn.fnamemodify(entry.cwd, ":~"), "Comment" } },
      virt_text_pos = "right_align",
    })
    cwds[id] = entry.cwd
  end
  vim.api.nvim_win_set_cursor(0, { #lines, 0 })

  vim.keymap.set("n", "<CR>", function()
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    local cmd = vim.api.nvim_get_current_line()
    local marks = vim.api.nvim_buf_get_extmarks(buf, ns, { lnum - 1, 0 }, { lnum - 1, -1 }, {})
    local cwd = marks[1] and cwds[marks[1][1]] or vim.fn.getcwd()
    vim.cmd("close")
    if cmd:match("%S") then
      run(cmd, cwd)
    end
  end, { buffer = buf, desc = "Run this command" })
  vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = buf, desc = "Close history" })
end

function M.rerun()
  if not last_run then
    return vim.notify("No previous test run", vim.log.levels.WARN)
  end
  run(last_run.cmd, last_run.cwd)
end

return M
