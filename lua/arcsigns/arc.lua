local M = {}

local function command_path(path)
  return vim.fn.fnamemodify(path, ':t')
end

function M.run(args, cwd, callback)
  if vim.fn.executable('arc') ~= 1 then
    callback(nil, 'arc executable was not found in PATH')
    return
  end
  local ok, err = pcall(vim.system, args, { cwd = cwd, text = true }, vim.schedule_wrap(function(result)
    if result.code ~= 0 then
      local message = vim.trim(result.stderr or '')
      if message == '' then message = vim.trim(result.stdout or '') end
      callback(nil, message ~= '' and message or ('exit code ' .. result.code))
    else
      callback(result.stdout or '', nil)
    end
  end))
  if not ok then callback(nil, tostring(err)) end
end

function M.blame(path, opts, callback)
  opts = opts or {}
  local range = opts.first and { '-L', ('%d,%d'):format(opts.first, opts.last or opts.first) } or {}
  local args = vim.list_extend({ 'arc', 'blame', '--json' }, range)
  args[#args + 1] = command_path(path)
  M.run(args, vim.fn.fnamemodify(path, ':h'), function(out, err)
    if err then callback(nil, err); return end
    local ok, data = pcall(vim.json.decode, out)
    if not ok or type(data) ~= 'table' or type(data.annotation) ~= 'table' then
      callback(nil, 'arc returned invalid blame JSON'); return
    end
    callback(data.annotation, nil)
  end)
end

function M.diff(path, callback)
  M.run({ 'arc', 'diff', '--git', '--no-color', '-U0', '--', command_path(path) }, vim.fn.fnamemodify(path, ':h'), callback)
end

function M.commit_summary(path, commit, callback)
  M.run({ 'arc', 'log', '-n', '1', '--oneline', commit }, vim.fn.fnamemodify(path, ':h'), function(out, err)
    if err then callback(nil, err); return end
    local summary = vim.trim((out or ''):match('^[^\n]*') or '')
    summary = summary:gsub('^%x+%s+', '')
    callback(summary, nil)
  end)
end

return M
