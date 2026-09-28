local M = {}

-- =========================
-- HIGHLIGHT DEFINITIONS
-- =========================
vim.api.nvim_set_hl(0, "KeymapsSectionOil", { bg = "#8fbcbb", fg = "#1e1e1e", bold = true })
vim.api.nvim_set_hl(0, "KeymapsSectionCmp", { bg = "#b48ead", fg = "#1e1e1e", bold = true })
vim.api.nvim_set_hl(0, "KeymapsSectionComment", { bg = "#bf616a", fg = "#1e1e1e", bold = true })
vim.api.nvim_set_hl(0, "Normal2", { bg = "#56B7C3", fg = "#1e1e1e", bold = true })
vim.api.nvim_set_hl(0, "Color1", { bg = "#D6ACFF", fg = "#1e1e1e", bold = true })
vim.api.nvim_set_hl(0, "Color2", { bg = "#F1FA8C", fg = "#1e1e1e", bold = true })
vim.api.nvim_set_hl(0, "Color3", { bg = "#FF79C6", fg = "#1e1e1e", bold = true })
vim.api.nvim_set_hl(0, "Color4", { bg = "#FF92DF", fg = "#1e1e1e", bold = true })
vim.api.nvim_set_hl(0, "Color5", { bg = "#69ff94", fg = "#1e1e1e", bold = true })
vim.api.nvim_set_hl(0, "Color6", { bg = "#FF6E6E", fg = "#1e1e1e", bold = true })
vim.api.nvim_set_hl(0, "Color7", { bg = "#D6ACFF", fg = "#1e1e1e", bold = true })

-- Highlight khusus untuk Status ON / OFF
vim.api.nvim_set_hl(0, "StatusOn", { fg = "#A3BE8C", bold = true }) -- Warna Hijau (Nord Green)
vim.api.nvim_set_hl(0, "StatusOff", { fg = "#BF616A", bold = true }) -- Warna Merah (Nord Red / Opsional)

local section_hl = {
	"KeymapsSectionOil",
	"KeymapsSectionCmp",
	"KeymapsSectionComment",
	"Normal2",
	"Color1",
	"Color2",
	"Color3",
	"Color4",
	"Color5",
	"Color6",
	"Color7",
}

local hl_index = 1
local function next_hl()
	local hl = section_hl[hl_index] or "Normal"
	hl_index = (hl_index % #section_hl) + 1
	return hl
end

-- =========================
-- BOOLEAN TABLE
-- =========================
function M.render_boolean_table(title, tbl)
	local lines = {}
	local highlights = {}

	local title_line = #lines
	table.insert(lines, " " .. title .. " ")
	table.insert(highlights, {
		line = title_line,
		col_start = 0,
		col_end = -1,
		hl = next_hl(),
	})

	table.insert(lines, string.rep("─", 45))
	table.insert(lines, string.format("%-22s %-10s", "NAME", "STATUS"))

	local keys = {}
	for key in pairs(tbl) do
		table.insert(keys, key)
	end
	table.sort(keys)

	for _, key in ipairs(keys) do
		local val = tbl[key]
		local status = val and "ON" or "OFF"
		local icon = val and "" or ""
		local line_text = string.format("%-22s %s %s", key, icon, status)

		local current_line_idx = #lines
		table.insert(lines, line_text)

		-- Berikan highlight hijau untuk status ON (atau merah untuk OFF)
		if val then
			table.insert(highlights, {
				line = current_line_idx,
				col_start = 23, -- Kolom dimulainya ikon/status
				col_end = -1,
				hl = "StatusOn",
			})
		else
			table.insert(highlights, {
				line = current_line_idx,
				col_start = 23,
				col_end = -1,
				hl = "StatusOff",
			})
		end
	end

	table.insert(lines, "")
	return lines, highlights
end

-- =========================
-- KEY VALUE TABLE
-- =========================
function M.render_key_value(title, tbl)
	local lines = {}
	local highlights = {}

	local title_line = #lines
	table.insert(lines, " " .. title .. " ")
	table.insert(highlights, {
		line = title_line,
		col_start = 0,
		col_end = -1,
		hl = next_hl(),
	})

	table.insert(lines, string.rep("─", 45))
	table.insert(lines, string.format("%-22s %-20s", "NAME", "VALUE"))

	-- Sort keys untuk konsistensi tampilan
	local keys = {}
	for k in pairs(tbl) do
		table.insert(keys, k)
	end
	table.sort(keys)

	for _, k in ipairs(keys) do
		table.insert(lines, string.format("%-22s %s", k, tbl[k]))
	end

	table.insert(lines, "")
	return lines, highlights
end

return M
