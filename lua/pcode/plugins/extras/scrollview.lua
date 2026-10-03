return {
	"dstein64/nvim-scrollview",
	event = { "BufReadPost", "BufNewFile" },
	opts = {
		excluded_filetypes = { "NvimTree", "vista_kind", "Outline", "neo-tree" },

		-- default-nya 'all'. Pilih sign group yang mau dipakai saja
		-- (tanpa 'diagnostics'), atau kosongkan {} untuk mematikan semua sign
		signs_on_startup = { "search", "cursor" },
	},
	config = function(_, opts)
		require("scrollview").setup(opts)

		-- warna scrollbar (pengganti bg/ctermbg di opts, yang bukan opsi valid)
		vim.api.nvim_set_hl(0, "ScrollView", { bg = "#4a5070", ctermbg = 60 })
	end,
}
