return {
	"brenton-leighton/multiple-cursors.nvim",
	version = "*",
	opts = {},
	event = { "BufRead", "InsertEnter", "BufNewFile" },
	keys = {
		-- 🧠 Seperti Ctrl + D di VS Code → pilih kata berikutnya yang sama
		{
			"<C-d>",
			function()
				vim.cmd("MultipleCursorsAddJumpNextMatch")
				vim.schedule(function()
					vim.notify(
						"🖊️ Multiple cursor: menambahkan seleksi berikutnya",
						vim.log.levels.INFO,
						{ title = "MultipleCursors" }
					)
				end)
			end,
			mode = { "n", "x" },
			desc = "Select next match",
		},

		-- 👇 Menambah kursor ke bawah seperti Ctrl + Alt + ↓
		{ "<C-M-Down>", "<Cmd>MultipleCursorsAddDown<CR>", mode = { "n", "i", "x" }, desc = "Add cursor down" },

		-- 👆 Menambah kursor ke atas seperti Ctrl + Alt + ↑
		{ "<C-M-Up>", "<Cmd>MultipleCursorsAddUp<CR>", mode = { "n", "i", "x" }, desc = "Add cursor up" },

		-- 🖱️ Tambah/hapus kursor dengan Ctrl + Klik mouse
		{
			"<M-LeftMouse>",
			"<Cmd>MultipleCursorsMouseAddDelete<CR>",
			mode = { "n", "i" },
			desc = "Add/remove cursor with mouse",
		},

		-- 🔲 Tambah kursor ke seluruh baris visual yang dipilih (pakai Leader + m)
		{ "<Leader>m", "<Cmd>MultipleCursorsAddVisualArea<CR>", mode = { "x" }, desc = "Add cursors to visual lines" },

		-- 🔒 Lock semua kursor supaya siap edit serentak
		{ "<Leader>L", "<Cmd>MultipleCursorsLock<CR>", mode = { "n", "x" }, desc = "Lock cursors" },
	},
}
