local Arc = require("arcsigns.arc")
local Diff = require("arcsigns.diff")
local Blame = require("arcsigns.blame")
local M = { ns = vim.api.nvim_create_namespace("arcsigns") }
M.config = { signcolumn = true, linehl = true, signs = { add = "▎", change = "▎", delete = "▁" } }

local function eligible(buf)
	local path = vim.api.nvim_buf_get_name(buf)
	return path ~= "" and vim.bo[buf].buftype == "" and vim.fn.filereadable(path) == 1
end

local function render(buf, text)
	if not eligible(buf) then
		return
	end
	vim.api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)
	local hunks = Diff.parse(text)
	for _, h in ipairs(hunks) do
		if h.new_count == 0 then
			local row = math.max(0, h.new_start - 1)
			vim.api.nvim_buf_set_extmark(buf, M.ns, row, 0, {
				sign_text = M.config.signs.delete,
				sign_hl_group = "ArcSignsDelete",
				line_hl_group = "ArcSignsDeleteLn",
			})
		else
			local hl = h.old_count == 0 and "ArcSignsAddLn" or "ArcSignsChangeLn"
			local sign = h.old_count == 0 and M.config.signs.add or M.config.signs.change
			for row = h.new_start, h.new_start + h.new_count - 1 do
				vim.api.nvim_buf_set_extmark(buf, M.ns, row - 1, 0, {
					sign_text = sign,
					sign_hl_group = hl:gsub("Ln$", ""),
					line_hl_group = M.config.linehl and hl or nil,
				})
			end
		end
	end
end

function M.refresh(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	if not eligible(buf) then
		return
	end
	local path = vim.api.nvim_buf_get_name(buf)
	Arc.diff(path, function(out, err)
		if vim.api.nvim_buf_is_valid(buf) then
			if err then
				vim.notify("Arc diff: " .. err, vim.log.levels.WARN)
				vim.api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)
			else
				render(buf, out)
			end
		end
	end)
end

function M.blame(opts)
	Blame.open(vim.api.nvim_get_current_buf(), opts)
end

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
	vim.fn.sign_define("ArcSignsAdd", { text = M.config.signs.add, texthl = "ArcSignsAdd" })
	vim.fn.sign_define("ArcSignsChange", { text = M.config.signs.change, texthl = "ArcSignsChange" })
	vim.fn.sign_define("ArcSignsDelete", { text = M.config.signs.delete, texthl = "ArcSignsDelete" })
	vim.api.nvim_set_hl(0, "ArcSignsAdd", { link = "DiffAdd" })
	vim.api.nvim_set_hl(0, "ArcSignsChange", { link = "DiffChange" })
	vim.api.nvim_set_hl(0, "ArcSignsDelete", { link = "DiffDelete" })
	vim.api.nvim_set_hl(0, "ArcSignsAddLn", { link = "DiffAdd" })
	vim.api.nvim_set_hl(0, "ArcSignsChangeLn", { link = "DiffChange" })
	vim.api.nvim_set_hl(0, "ArcSignsDeleteLn", { link = "DiffDelete" })
	vim.api.nvim_create_user_command("ArcSignsRefresh", function()
		M.refresh()
	end, {})
	vim.api.nvim_create_user_command("ArcSignsBlame", function()
		M.blame()
	end, {})
	vim.keymap.set("n", "<leader>ab", "<cmd>ArcSignsBlame<cr>", { silent = true, desc = "Arc blame" })
	vim.keymap.set("n", "<leader>ar", "<cmd>ArcSignsRefresh<cr>", { silent = true, desc = "Refresh Arc signs" })
	local group = vim.api.nvim_create_augroup("arcsigns", { clear = true })
	vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "BufWinEnter" }, {
		group = group,
		callback = function(ev)
			M.refresh(ev.buf)
		end,
	})
end

return M
