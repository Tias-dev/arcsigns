local Arc = require('arcsigns.arc')
local M = {}

local panel_ns = vim.api.nvim_create_namespace('arcsigns_blame_panel')
local float_win
vim.api.nvim_set_hl(0, 'ArcSignsBlameAuthor', { link = 'Identifier', default = true })
vim.api.nvim_set_hl(0, 'ArcSignsBlameDate', { link = 'Constant', default = true })
vim.api.nvim_set_hl(0, 'ArcSignsBlameHash', { link = 'Special', default = true })
local hash_colors = {}

local function hash_hl(hash)
  local key = tostring(hash):sub(1, 6)
  if key == '' then return 'ArcSignsBlameHash' end
  if not hash_colors[key] then
    local r, g, b = key:match('(%x)(%x)(%x)')
    if r and g and b then
      local function channel(x)
        return math.min(0xdf, 0x20 + math.floor((tonumber(x, 16) * 0x10 + (15 - tonumber(x, 16))) * 0.75))
      end
      local color = channel(r) * 0x10000 + channel(g) * 0x100 + channel(b)
      hash_colors[key] = 'ArcSignsBlameHash' .. key
      vim.api.nvim_set_hl(0, hash_colors[key], { fg = string.format('#%06x', color) })
    else
      hash_colors[key] = 'ArcSignsBlameHash'
    end
  end
  return hash_colors[key]
end
local function valid(buf) return buf and vim.api.nvim_buf_is_valid(buf) end

local function format_line(item, width, graph, first)
  local hash = tostring(item.commit or ''):sub(1, 9)
  local author = tostring(item.author or '')
  local date = tostring(item.date or ''):sub(1, 10)
  if not first then return graph .. string.rep(' ', 13 + width + 11) end
  local prefix = graph .. ' ' .. ('%-9s '):format(hash) .. ('%-' .. width .. 's'):format(author) .. (' %s '):format(date)
  return prefix .. tostring(item.summary or ''):gsub('[\r\n]+$', '')
end

function M.open(source, opts)
  opts = opts or {}
  if not valid(source) then return end
  local path = vim.api.nvim_buf_get_name(source)
  if path == '' or vim.bo[source].buftype ~= '' then
    vim.notify('Arc blame needs a file buffer', vim.log.levels.WARN); return
  end
  local source_win = vim.fn.bufwinid(source)
  if source_win == -1 then return end
  Arc.blame(path, opts, function(entries, err)
    if err then vim.notify('Arc blame: ' .. err, vim.log.levels.ERROR); return end
    if not entries or #entries == 0 then vim.notify('Arc returned no blame annotations', vim.log.levels.WARN); return end
    local unique, pending = {}, 0
    for _, entry in ipairs(entries) do
      local commit = tostring(entry.commit or '')
      if commit ~= '' and not unique[commit] then unique[commit] = true; pending = pending + 1 end
    end
    local function continue_render()
    local widths = 0
    for _, e in ipairs(entries) do widths = math.max(widths, vim.fn.strdisplaywidth(tostring(e.author or ''))) end
    vim.api.nvim_set_current_win(source_win)
    vim.cmd('leftabove 42vsplit')
    local panel_win = vim.api.nvim_get_current_win()
    local panel = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(panel_win, panel)
    vim.bo[panel].buftype, vim.bo[panel].bufhidden, vim.bo[panel].swapfile = 'nofile', 'wipe', false
    vim.bo[panel].filetype, vim.bo[panel].modifiable = 'arcsigns-blame', false
    vim.wo[panel_win].number, vim.wo[panel_win].relativenumber = false, false
    vim.wo[panel_win].signcolumn, vim.wo[panel_win].wrap = 'no', false
    local lines = {}
    local graphs = {}
    local first_lines = {}
    local previous
    for i, entry in ipairs(entries) do
      local current = tostring(entry.commit or '')
      local next_commit = entries[i + 1] and tostring(entries[i + 1].commit or '') or nil
      if current == previous then
      graphs[i] = current == next_commit and '│' or '┕'
      else
        graphs[i] = current == next_commit and '┍' or '╺'
      end
      first_lines[i] = current ~= previous
      lines[#lines + 1] = format_line(entry, widths, graphs[i], first_lines[i])
      previous = current
    end
    vim.bo[panel].modifiable = true
    vim.api.nvim_buf_set_lines(panel, 0, -1, false, lines)
    vim.bo[panel].modifiable = false
    vim.api.nvim_buf_set_name(panel, 'Arc blame: ' .. vim.fn.fnamemodify(path, ':t'))
    vim.api.nvim_buf_clear_namespace(panel, panel_ns, 0, -1)
    for i, e in ipairs(entries) do
      local hash = tostring(e.commit or '')
      if #hash >= 8 then
        local hash_start = 2
        vim.api.nvim_buf_set_extmark(panel, panel_ns, i - 1, hash_start, {
          end_col = hash_start + math.min(9, #hash), hl_group = hash_hl(hash),
          url = 'https://a.yandex-team.ru/arcadia/commit/' .. hash,
        })
        vim.api.nvim_buf_set_extmark(panel, panel_ns, i - 1, 0, {
          end_col = 1, hl_group = hash_hl(hash),
        })
        if first_lines[i] then
          vim.api.nvim_buf_set_extmark(panel, panel_ns, i - 1, 12, {
            end_col = 12 + vim.fn.strdisplaywidth(tostring(e.author or '')), hl_group = 'ArcSignsBlameAuthor',
          })
          local date_col = 13 + widths
          vim.api.nvim_buf_set_extmark(panel, panel_ns, i - 1, date_col, {
            end_col = date_col + #tostring(e.date or ''):sub(1, 10), hl_group = 'ArcSignsBlameDate',
          })
        end
      end
    end
    vim.keymap.set('n', 'q', '<cmd>close<cr>', { buffer = panel, silent = true })
    vim.keymap.set('n', '<CR>', function()
      local row = vim.api.nvim_win_get_cursor(0)[1]
      local hash = tostring(entries[row] and entries[row].commit or '')
      if #hash >= 8 then vim.ui.open('https://a.yandex-team.ru/arcadia/commit/' .. hash) end
    end, { buffer = panel, silent = true })
    vim.api.nvim_create_autocmd('CursorMoved', { buffer = source, callback = function()
      if valid(panel) and vim.api.nvim_win_is_valid(panel_win) then
        local row = math.min(vim.api.nvim_win_get_cursor(source_win)[1], #entries)
        vim.api.nvim_win_set_cursor(panel_win, { row, 0 })
      end
      local row = vim.api.nvim_win_get_cursor(source_win)[1]
      local summary = entries[row] and entries[row].summary
      if summary and summary ~= '' then
        if float_win and vim.api.nvim_win_is_valid(float_win) then vim.api.nvim_win_close(float_win, true) end
        local lines = vim.split(summary, '\n', { plain = true })
        local buf
        buf, float_win = vim.lsp.util.open_floating_preview(lines, 'text', { focus = false, border = 'rounded', relative = 'cursor', row = 1, col = 0, max_width = 80 })
        vim.bo[buf].modifiable = false
      elseif float_win and vim.api.nvim_win_is_valid(float_win) then
        vim.api.nvim_win_close(float_win, true); float_win = nil
      end
    end })
    vim.api.nvim_create_autocmd('WinClosed', { pattern = tostring(panel_win), once = true, callback = function() if valid(panel) then vim.api.nvim_buf_delete(panel, { force = true }) end end })
    vim.api.nvim_create_autocmd({ 'BufWipeout', 'BufHidden' }, { buffer = source, callback = function()
      if float_win and vim.api.nvim_win_is_valid(float_win) then vim.api.nvim_win_close(float_win, true); float_win = nil end
    end })
    vim.api.nvim_exec_autocmds('CursorMoved', { buffer = source, modeline = false })
    end
    if pending == 0 then continue_render(); return end
    for commit in pairs(unique) do
      Arc.commit_summary(path, commit, function(summary)
        for _, entry in ipairs(entries) do
          if tostring(entry.commit or '') == commit then entry.summary = summary or '' end
        end
        pending = pending - 1
        if pending == 0 then continue_render() end
      end)
    end
  end)
end

return M
