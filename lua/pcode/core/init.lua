-- ============================================================================
-- PCode Neovim Core Initializer
-- ============================================================================
_G.pcode = _G.pcode or {}

-- 1. Preferensi pengguna & flag fitur (pcode.lang, pcode.extras, pcode.themes)
require("pcode.user.default")

-- 2. Terminal helpers global (_G.LAZYGIT_TOGGLE, _G.LAZYDOCKER_TOGGLE)
require("pcode.core.terminal")

-- 3. Opsi editor dasar & filetype detection (dimuat sebelum plugin)
require("pcode.user.options")

-- 4. Pemetaan tombol (keymaps)
require("pcode.user.keymaps")

-- 5. Autocommands & user commands kustom
require("pcode.user.autocmd")

-- 6. Plugin manager (lazy.nvim)
require("pcode.config.lazy_config")

-- 7. Aplikasi colorscheme aktif
require("pcode.user.colorscheme")

-- 8. Tool runtime & integrasi bahasa
require("pcode.user.ts_queries").setup()
require("pcode.user.compare")
require("pcode.user.bgrun").setup()
require("pcode.user.cfml_rainbow").setup({ "cfml" })

-- 9. Utility khusus macOS
if vim.fn.has("mac") == 1 then
	require("pcode.user.dotclean")
end
