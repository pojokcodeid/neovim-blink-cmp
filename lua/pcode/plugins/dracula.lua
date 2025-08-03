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
				NeoTreeTabActive = { link = "ColorColumn" },
				BlinkCmpGhostText = { link = "Comment" },
				illuminatedWord = { bg = "#3b4261" },
				illuminatedCurWord = { bg = "#3b4261" },
				IlluminatedWordText = { bg = "#3b4261" },
				IlluminatedWordRead = { bg = "#3b4261" },
				IlluminatedWordWrite = { bg = "#3b4261" },
			},
			transparent_bg = false,
		}
	end,
	config = function(_, opts)
		require("dracula").setup(opts)
		vim.cmd("colorscheme dracula")
	end,
}
