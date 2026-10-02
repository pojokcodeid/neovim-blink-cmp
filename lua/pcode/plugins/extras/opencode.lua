return {
	"nickjvandyke/opencode.nvim",
	event = "VeryLazy",
	dependencies = {
		"nvim-lua/plenary.nvim",
	},
	config = function()
		-- Mengirimkan konfigurasi melalui global variable vim.g sebelum inisialisasi
		vim.g.opencode_opts = {
			server = {
				connect = true,
				username = vim.env.OPENCODE_SERVER_USERNAME or "opencode",
				password = "rahasia",
			},
		}
		-- Recommended/example keymaps
		vim.keymap.set({ "n", "x" }, "<C-a>", function()
			require("opencode").ask("@this: ")
		end, { desc = "Ask OpenCode…" })
		vim.keymap.set({ "n", "x" }, "<C-x>", function()
			require("opencode").select()
		end, { desc = "Select OpenCode…" })
		vim.keymap.set({ "n", "x" }, "go", function()
			return require("opencode").operator("@this")
		end, { desc = "Send range to OpenCode", expr = true })
		vim.keymap.set({ "n" }, "goo", function()
			return require("opencode").operator("@this") .. "_"
		end, { desc = "Send line to OpenCode", expr = true })
	end,
}
