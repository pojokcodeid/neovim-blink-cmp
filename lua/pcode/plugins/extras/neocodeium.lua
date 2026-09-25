return {
	"monkoose/neocodeium",
	event = "VeryLazy",
	dependencies = { "saghen/blink.cmp" },
	config = function()
		local neocodeium = require("neocodeium")
		local blink = require("blink.cmp")

		-- Konfigurasi Neocodeium & integrasi Blink CMP
		neocodeium.setup({
			-- Mencegah Neocodeium tampil saat popup blink.cmp sedang aktif
			filter = function()
				return not blink.is_visible()
			end,
			-- Penanganan marker agar aman di Neovim 0.12 (Nightly)
			root_dir = function(bufnr)
				return vim.fs.root(bufnr, { ".git", "package.json", "Makefile", "Cargo.toml", "go.mod" })
			end,
		})

		-- Bersihkan saran Neocodeium saat menu Blink CMP terbuka
		vim.api.nvim_create_autocmd("User", {
			pattern = "BlinkCmpMenuOpen",
			callback = function()
				neocodeium.clear()
			end,
		})

		-- Picu ulang saran Neocodeium saat menu Blink CMP ditutup
		vim.api.nvim_create_autocmd("User", {
			pattern = "BlinkCmpMenuClose",
			callback = function()
				neocodeium.cycle_or_complete()
			end,
		})

		-- =========================
		-- Keymaps
		-- =========================
		vim.keymap.set("i", "<C-g>", neocodeium.accept, { desc = "Codeium Accept" })
		vim.keymap.set("i", "<C-S-g>", neocodeium.accept, { desc = "Codeium Accept" })
		vim.keymap.set("i", "<C-x>", neocodeium.clear, { desc = "Codeium Clear" })
		vim.keymap.set("i", "<C-S-x>", neocodeium.clear, { desc = "Codeium Clear" })
		vim.keymap.set("i", "<C-Up>", function()
			neocodeium.cycle(-1)
		end, { desc = "Codeium Cycle Prev" })
		vim.keymap.set("i", "<C-Down>", function()
			neocodeium.cycle(1)
		end, { desc = "Codeium Cycle Next" })
		vim.keymap.set("i", "<C-S-Up>", function()
			neocodeium.cycle(-1)
		end, { desc = "Codeium Cycle Prev" })
		vim.keymap.set("i", "<C-S-Down>", function()
			neocodeium.cycle(1)
		end, { desc = "Codeium Cycle Next" })

		-- =========================
		-- Commands
		-- =========================
		vim.api.nvim_create_user_command("CodeiumDisable", function()
			require("neocodeium.commands").disable(true)
		end, {})

		vim.api.nvim_create_user_command("CodeiumEnable", function()
			require("neocodeium.commands").enable()
		end, {})
	end,
}
