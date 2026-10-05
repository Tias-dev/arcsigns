local M = {}

local function number(value) return tonumber(value) or 0 end

function M.parse(text)
  local hunks = {}
  for line in (text or ''):gmatch('[^\n]+') do
    local old_start, old_count, new_start, new_count = line:match('^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@')
    if old_start then
      old_count = old_count == '' and 1 or number(old_count)
      new_count = new_count == '' and 1 or number(new_count)
      hunks[#hunks + 1] = {
        old_start = number(old_start), old_count = old_count,
        new_start = number(new_start), new_count = new_count,
      }
    end
  end
  return hunks
end

return M
