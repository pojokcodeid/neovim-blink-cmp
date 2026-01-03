return {
	"ellisonleao/gruvbox.nvim",
	priority = 1000,
	opts = function()
		local color = require("gruvbox").palette
		return {
			transparent_mode = true,
			terminal_colors = true, -- add neovim terminal colors
			undercurl = false,
			underline = false,
			bold = false,
			contrast = "", -- can be "hard", "soft" or empty string
			palette_overrides = {},
			overrides = {
				["Normal"] = { bg = color.dark0, fg = color.light1 },
				["NormalFloat"] = { bg = "NONE" },
				["NormalNC"] = { bg = "NONE" },
				["MiniIndentscopeSymbol"] = { fg = color.bright_yellow },
				["StatusLine"] = { bg = "NONE" },
				["FoldColumn"] = { bg = "NONE" },
				["Folded"] = { bg = "NONE" },
				["SignColumn"] = { bg = "NONE" },
				["MasonBackdrop"] = { link = "NormalFloat" },
				["TabLineFill"] = { link = "NormalFloat" },
				["WinBar"] = { link = "NormalFloat" },
				["WinBarNC"] = { link = "NormalFloat" },
				["NotifyBackground"] = { bg = "#282828" },
				["NormalTab"] = { bg = color.dark0, fg = color.light1 },
				["ColorColumnTab"] = { bg = color.dark1 },
			},
		}
	end,
	config = function(_, opts)
		vim.o.background = "dark"
		require("gruvbox").setup(opts)
	end,
}
