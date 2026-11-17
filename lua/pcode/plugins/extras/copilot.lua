return {
	"zbirenbaum/copilot.lua",
	cmd = "Copilot",
	event = "InsertEnter",
	dependencies = { "saghen/blink.cmp" },
	config = function()
		require("copilot").setup({
			panel = { enabled = false },
			suggestion = {
				enabled = true,
				auto_trigger = true,
				-- keymap diatur manual di bawah
				keymap = {
					accept = false,
					accept_word = false,
					accept_line = false,
					next = false,
					prev = false,
					dismiss = false,
				},
			},
		})

		local suggestion = require("copilot.suggestion")

		-- =========================
		-- Integrasi Blink CMP
		-- Sembunyikan saran Copilot saat menu blink terbuka
		-- =========================
		vim.api.nvim_create_autocmd("User", {
			pattern = "BlinkCmpMenuOpen",
			callback = function()
				vim.b.copilot_suggestion_hidden = true
			end,
		})

		vim.api.nvim_create_autocmd("User", {
			pattern = "BlinkCmpMenuClose",
			callback = function()
				vim.b.copilot_suggestion_hidden = false
			end,
		})

		-- =========================
		-- Keymaps (sama seperti sebelumnya)
		-- =========================
		local map = vim.keymap.set

		for _, lhs in ipairs({ "<C-g>", "<C-S-g>" }) do
			map("i", lhs, function()
				if suggestion.is_visible() then
					suggestion.accept()
				end
			end, { desc = "Copilot Accept" })
		end

		for _, lhs in ipairs({ "<C-x>", "<C-S-x>" }) do
			map("i", lhs, suggestion.dismiss, { desc = "Copilot Clear" })
		end

		for _, lhs in ipairs({ "<C-Up>", "<C-S-Up>" }) do
			map("i", lhs, suggestion.prev, { desc = "Copilot Cycle Prev" })
		end

		for _, lhs in ipairs({ "<C-Down>", "<C-S-Down>" }) do
			map("i", lhs, suggestion.next, { desc = "Copilot Cycle Next" })
		end

		-- =========================
		-- Commands
		-- =========================
		vim.api.nvim_create_user_command("AIDisable", function()
			vim.cmd("Copilot disable")
		end, {})

		vim.api.nvim_create_user_command("AIEnable", function()
			vim.cmd("Copilot enable")
		end, {})
	end,
}
