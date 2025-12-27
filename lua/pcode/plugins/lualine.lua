return {
	{
		"pojokcodeid/auto-lualine.nvim",
		event = { "InsertEnter", "BufRead", "BufNewFile" },
		dependencies = { "nvim-lualine/lualine.nvim" },
		opts = {
			-- for more options check out https://github.com/pojokcodeid/auto-lualine.nvim
			setColor = "auto",
			setOption = "roundedall",
			setMode = 5,
		},
	},
}
