local M = {}

-- HIGHLIGHT
vim.api.nvim_set_hl(0, "PcodeHeaderTitle", { bg = "#FFCDC9", fg = "#1e1e1e", bold = true })

function M.render()
	local lines = {
		"  Command: ",
		"   PCodeAdd         => Command for active plugin config  ",
		"   PCodeRemove      => Command for remove plugin config  ",
		"   Theme            => Command for change theme ",
		"",
	}

	local highlights = {
		{
			line = 0,
			col_start = 0,
			col_end = -1,
			hl = "PcodeHeaderTitle",
		},
	}

	return lines, highlights
end

return M
