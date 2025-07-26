return {
	"Mofiqul/dracula.nvim",
	priority = 1000,
	opts = function()
		local colors = require("dracula").colors()
		return {
			colors = {
				menu = colors.bg,
				selection = "#363848",
			},
			italic_comment = true,
			lualine_bg_color = colors.bg,
			overrides = {
				StatusLine = { fg = colors.fg, bg = colors.bg },
				BufferLineFill = { bg = colors.bg },
				Pmenu = { fg = colors.fg, bg = colors.bg },
				WinBar = { bg = colors.bg },
				WinBarNC = { fg = colors.fg, bg = colors.bg },
				MasonBackdrop = { link = "NormalFloat" },
				NeoTreeDirectoryIcon = { fg = "#6776a7" },
				NeoTreeTabInactive = { fg = "#6776a7", bg = colors.bg },
				NeoTreeTabSeparatorActive = { fg = "#6776a7", bg = colors.bg },
				NeoTreeTabSeparatorInactive = { fg = "#6776a7", bg = colors.bg },
				NeoTreeTabActive = { fg = colors.fg, bg = colors.selection },
			},
			transparent_bg = false,
		}
	end,
	config = function(_, opts)
		require("dracula").setup(opts)
		vim.cmd("colorscheme dracula")
	end,
}
