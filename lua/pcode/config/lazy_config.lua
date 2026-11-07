-- ============================================================================
-- Lazy.nvim Plugin Manager Bootstrap & Setup
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

local icons = require("pcode.user.icons").ui

-- ============================================================================
-- Plugin Spec Construction
-- ============================================================================
local spec = {
	{ import = "pcode.plugins" }, -- Plugin utama di lua/pcode/plugins/
}

--- Tambahkan import "<prefix>.<key>" ke spec jika diaktifkan di konfigurasi.
---@param prefix string
---@param tbl table
---@param only_enabled boolean?
local function add_imports(prefix, tbl, only_enabled)
	for key, value in pairs(tbl or {}) do
		if not only_enabled or value then
			spec[#spec + 1] = { import = prefix .. "." .. key }
		end
	end
end

-- Import tema, fitur extras aktif, dan modul bahasa aktif
add_imports("pcode.plugins.theme", pcode.themes or {})
add_imports("pcode.plugins.extras", pcode.extras or {}, true)
add_imports("pcode.plugins.lang", pcode.lang or {}, true)

-- Plugin kustom user (selalu paling akhir untuk prioritas override)
spec[#spec + 1] = { import = "pcode.user.custom" }

-- ============================================================================
-- Setup Lazy.nvim
-- ============================================================================
require("lazy").setup({
	spec = spec,
	ui = {
		backdrop = 100,
		border = "rounded",
		browser = "chrome",
		throttle = 40,
		custom_keys = {
			["<localleader>l"] = false,
		},
		icons = {
			ft = icons.ft,
			lazy = icons.Bell .. " ",
			loaded = icons.CheckCircle,
			not_loaded = icons.not_loaded,
		},
	},
	change_detection = {
		enabled = false,
		notify = false,
	},
	checker = {
		enabled = true, -- Cek update plugin secara berkala di background
	},
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
