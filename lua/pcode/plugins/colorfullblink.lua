return {
	"saghen/blink.cmp",
	dependencies = {
		"xzbdmw/colorful-menu.nvim",
	},
	opts = function(_, opts)
		opts.completion.menu.draw.components = {
			label = {
				text = require("colorful-menu").blink_components_text,
				highlight = require("colorful-menu").blink_components_highlight,
			},
		}
	end,
}
