--[[ return {
	"saghen/blink.cmp",
	dependencies = {
		{
			"Exafunction/codeium.nvim",
			cmd = "Codeium",
			build = ":Codeium Auth",
			opts = {
				enable_chat = true,
				enable_cmp_source = false, -- true jika menggunkan nvim-cmp
				virtual_text = {
					enabled = false, -- true jika ingin mengactivekan virtual text sugetion
					key_bindings = {
						accept = "<c-g>",
						next = "<c-Down>",
						prev = "<c-Up>",
					},
				},
			},
			config = function(_, opts)
				require("codeium").setup(opts)
			end,
		},
	},
	opts = function(_, opts)
		table.insert(opts.sources.default, 1, "codeium")
		opts.sources.providers.codeium = { name = "Codeium", module = "codeium.blink", async = true }
	end,
} ]]

return {}
