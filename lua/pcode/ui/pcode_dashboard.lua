local popup = require("pcode.ui.popup")
local renderer = require("pcode.ui.table_renderer")

local M = {}

function M.open()
	local pcode = _G.pcode
	if not pcode then
		vim.notify("pcode config belum dimuat", vim.log.levels.ERROR)
		return
	end

	local lines = {}
	local highlights = {}

	local function append(block, hls)
		local offset = #lines
		vim.list_extend(lines, block)
		for _, h in ipairs(hls) do
			table.insert(highlights, {
				line = h.line + offset,
				col_start = h.col_start,
				col_end = h.col_end,
				hl = h.hl,
			})
		end
	end

	append(renderer.render_boolean_table("Languages", pcode.lang or {}))
	append(renderer.render_boolean_table("Extras", pcode.extras or {}))
	append(renderer.render_key_value("Themes", pcode.themes or {}))

	append(renderer.render_key_value("Flags", {
		transparent = pcode.transparent,
		localcode = pcode.localcode,
		use_nvimtree = pcode.use_nvimtree,
		nvimtree_float = pcode.nvimtree_float,
	}))

	popup.open({
		title = "PCODE CONFIGURATION",
		content = lines,
		highlights = highlights,
		filetype = "markdown",
		width = math.floor(vim.o.columns * 0.85),
		height = math.floor(vim.o.lines * 0.85),
	})
end

return M
