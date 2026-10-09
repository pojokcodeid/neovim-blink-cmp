-- ============================================================================
-- Bootstrap lazy.nvim
-- ============================================================================
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local out = vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"--branch=stable",
		"https://github.com/folke/lazy.nvim.git",
		lazypath,
	})

	if vim.v.shell_error ~= 0 then
		vim.api.nvim_echo({
			{ "Failed to clone lazy.nvim:\n", "ErrorMsg" },
			{ out, "WarningMsg" },
			{ "\nPress any key to exit..." },
		}, true, {})
		vim.fn.getchar()
		os.exit(1)
	end
end

vim.opt.rtp:prepend(vim.env.LAZY or lazypath)

-- ============================================================================
-- Pengaturan dasar (harus sebelum lazy.nvim di-load agar mapping benar)
-- ============================================================================
vim.opt.number = false
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

local icons = require("pcode.user.icons").ui

-- ============================================================================
-- Daftar import plugin
-- ============================================================================
local spec = { { import = "pcode.plugins" } }

--- Tambahkan import "<prefix>.<key>" ke spec.
--- Jika `only_enabled` true, hanya key dengan nilai truthy yang di-import.
local function add_imports(prefix, tbl, only_enabled)
	for key, value in pairs(tbl) do
		if not only_enabled or value then
			spec[#spec + 1] = { import = prefix .. "." .. key }
		end
	end
end

add_imports("pcode.plugins.theme", pcode.themes or {}) -- theme (semua key)
add_imports("pcode.plugins.extras", pcode.extras or {}, true) -- extras aktif
add_imports("pcode.plugins.lang", pcode.lang or {}, true) -- bahasa aktif

--[[ Transparent config
if pcode.transparent then
	spec[#spec + 1] = { import = "pcode.plugins.extras.transparent" }
end ]]

-- Override path (selalu terakhir)
spec[#spec + 1] = { import = "pcode.user.custom" }

-- ============================================================================
-- Setup lazy.nvim
-- ============================================================================
require("lazy").setup({
	spec = spec,
	ui = {
		backdrop = 100,
		border = "rounded",
		browser = "chrome", -- Chrome sebagai browser default
		throttle = 40,
		custom_keys = {
			["<localleader>l"] = false, -- Nonaktifkan localleader l
		},
		icons = {
			ft = icons.ft,
			lazy = icons.Bell .. " ",
			loaded = icons.CheckCircle,
			not_loaded = icons.not_loaded,
		},
	},
	change_detection = { enabled = false, notify = false },
	checker = { enabled = true }, -- Cek update plugin otomatis
	performance = {
		rtp = {
			disabled_plugins = {
				"gzip",
				"matchit",
				"matchparen",
				"netrwPlugin",
				"tarPlugin",
				"tohtml",
				"tutor",
				"zipPlugin",
			},
		},
	},
})
