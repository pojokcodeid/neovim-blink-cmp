return {
	"akinsho/bufferline.nvim",
	branch = "main",
	event = { "BufRead", "InsertEnter", "BufNewFile" },
	dependencies = "pojokcodeid/auto-bufferline.nvim",
	config = function()
		vim.opt.termguicolors = true
		local config = require("auto-bufferline").config()
		require("bufferline").setup(config)
	end,
}
