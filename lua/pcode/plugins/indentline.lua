return {
	"shellRaining/hlchunk.nvim",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		require("hlchunk").setup({
			chunk = {
				enable = true,
				-- ...
			},
			indent = {
				enable = true,
				style = {
					vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID("Whitespace")), "fg", "gui"),
				},
				-- ...
			},
			exclude_filetypes = {
				aerial = true,
				dashboard = true,
				alpha = true,
				-- some other filetypes
			},
		})
	end,
}
