local M = {}

-- HIGHLIGHT
vim.api.nvim_set_hl(0, "PcodeHeaderTitle", { fg = "#E5E9F0", bold = true })

function M.render()
	local lines = {
		"Command:",
		"  PCodeAddExtra    => Command for active extra config  ",
		"  PCodeRemoveExtra => Command for remove extra config  ",
		"  PCodeAddLang     => Command for active language config  ",
		"  PCodeRemoveLang  => Command for remove language config  ",
		"  Theme            => Command for change theme ",
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
