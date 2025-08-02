return {
	"saghen/blink.cmp",
	dependencies = {
		"mikavilpas/blink-ripgrep.nvim",
	},
	opts = function(_, opts)
		table.insert(opts.sources.default, 1, "ripgrep")
		opts.sources.providers.ripgrep = {
			module = "blink-ripgrep",
			name = "Ripgrep",
			opts = {
				prefix_min_len = 3,
				backend = {
					context_size = 5,
					ripgrep = {
						max_filesize = "1M",
						additional_rg_options = {},
					},
				},
			},
			transform_items = function(_, items)
				for _, item in ipairs(items) do
					item.kind_name = "Ripgrep"
				end
				return items
			end,
		}
	end,
}
