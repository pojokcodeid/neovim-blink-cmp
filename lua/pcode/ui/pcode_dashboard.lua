local popup = require("pcode.ui.popup")
local loader = require("pcode.core.default_loader")
local render = require("pcode.ui.table_renderer")

local M = {}

function M.open()
	local cfg = loader.load()
	if not cfg then
		return
	end

	local lines = {}

	vim.list_extend(lines, render.render_boolean_table("Languages", cfg.lang or {}))

	vim.list_extend(lines, render.render_boolean_table("Extras", cfg.extras or {}))

	vim.list_extend(lines, render.render_key_value("Theme", cfg.themes or {}))

	vim.list_extend(
		lines,
		render.render_key_value("Flags", {
			transparent = cfg.transparent,
			localcode = cfg.localcode,
			use_nvimtree = cfg.use_nvimtree,
			nvimtree_float = cfg.nvimtree_float,
		})
	)

	popup.open({
		title = "PCODE CONFIGURATION",
		content = lines,
		filetype = "markdown",
		width = math.floor(vim.o.columns * 0.8),
		height = math.floor(vim.o.lines * 0.8),
	})
end

return M
