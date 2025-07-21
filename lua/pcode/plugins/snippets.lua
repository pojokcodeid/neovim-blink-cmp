return {
	"rafamadriz/friendly-snippets",
	event = "InsertEnter",
	lazy = true,
	config = function()
		require("luasnip.loaders.from_vscode").lazy_load()
		require("pcode.user.snippets")
	end,
}
