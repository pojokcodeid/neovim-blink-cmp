-- ============================================================================
-- Options & FileType Configuration
-- ============================================================================

-- Leader key (harus diset sebelum mapping atau plugin dimuat)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

local options = {
	-- ------------------------------------------------------------------------
	-- General & System
	-- ------------------------------------------------------------------------
	fileencoding = "utf-8", -- Pengkodean file untuk buffer
	clipboard = "unnamedplus", -- Koneksi ke clipboard sistem
	mouse = "a", -- Dukungan mouse di semua mode
	history = 100, -- Jumlah baris riwayat perintah
	timeoutlen = 300, -- Waktu tunggu sequence shortcut (ms)
	updatetime = 300, -- Waktu tunggu sebelum event trigger / swap (ms)
	lazyredraw = false, -- Layar tidak digambar ulang secara malas

	-- ------------------------------------------------------------------------
	-- Appearance & UI
	-- ------------------------------------------------------------------------
	termguicolors = true, -- Aktifkan warna RGB 24-bit
	cursorline = true, -- Sorot baris teks kursor saat ini
	signcolumn = "yes", -- Selalu tampilkan kolom tanda (sign column)
	laststatus = 3, -- Global statusline (1 statusline untuk semua window)
	showtabline = 2, -- Selalu tampilkan tabline di atas
	showmode = false, -- Mode (INSERT, NORMAL, dsb.) disembunyikan (sudah di statusline)
	cmdheight = 0, -- Sembunyikan command line kecuali sedang digunakan
	pumheight = 10, -- Tinggi maksimum popup menu
	fillchars = { eob = " " }, -- Hilangkan simbol '~' di akhir buffer
	guifont = "Hasklug Nerd Font:h15", -- Font untuk GUI Neovim
	guicursor = "n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50,a:blinkwait700-blinkoff400-blinkon250-Cursor/lCursor,sm:block-blinkwait175-blinkoff150-blinkon175",

	-- ------------------------------------------------------------------------
	-- Line Numbers
	-- ------------------------------------------------------------------------
	number = true, -- Tampilkan nomor baris
	relativenumber = true, -- Tampilkan nomor baris relatif

	-- ------------------------------------------------------------------------
	-- Indentation & Tabs (Default: 2 spaces)
	-- ------------------------------------------------------------------------
	expandtab = true, -- Gunakan spasi untuk menggantikan tab
	shiftwidth = 2, -- Jumlah spasi per tingkat indentasi
	tabstop = 2, -- Jumlah spasi per tab
	copyindent = true, -- Salin indentasi baris sebelumnya
	preserveindent = true, -- Pertahankan struktur indentasi sebisa mungkin

	-- ------------------------------------------------------------------------
	-- Search & Cursor Navigation
	-- ------------------------------------------------------------------------
	ignorecase = true, -- Pencarian case-insensitive
	smartcase = true, -- Case-sensitive otomatis jika ada huruf kapital
	whichwrap = "bs<>[]hl", -- Tombol navigasi yang boleh pindah ke baris lain
	backspace = vim.opt.backspace + { "nostop" }, -- Jangan hentikan backspace di insert mode
	scrolloff = 8, -- Jaga minimal 8 baris di atas/bawah kursor saat scroll
	sidescrolloff = 8, -- Jaga minimal 8 kolom di kiri/kanan kursor saat scroll
	wrap = false, -- Jangan bungkus baris yang melebihi lebar jendela

	-- ------------------------------------------------------------------------
	-- Windows & Splits
	-- ------------------------------------------------------------------------
	splitbelow = true, -- Split horizontal terbuka di bagian bawah
	splitright = true, -- Split vertikal terbuka di bagian kanan

	-- ------------------------------------------------------------------------
	-- Backup & Swapfiles
	-- ------------------------------------------------------------------------
	swapfile = false, -- Jangan buat file swap .swp
	writebackup = false, -- Jangan buat backup sebelum menimpa file
	undofile = true, -- Aktifkan persistent undo history

	-- ------------------------------------------------------------------------
	-- Completion
	-- ------------------------------------------------------------------------
	completeopt = { "menuone", "noselect" }, -- Opsi completion mode insert
}

-- Terapkan semua opsi
for k, v in pairs(options) do
	vim.opt[k] = v
end

-- ============================================================================
-- FileType Detection Custom
-- ============================================================================
vim.filetype.add({
	extension = {
		cfm = "cfml",
		cfml = "cfml",
		cfc = "cfml",
		sfc = "cfml",
		cfs = "cfscript",
		jsx = "javascriptreact",
		zsh = "zsh",
		command = "zsh",
		js = "javascriptreact",
	},
	filename = {
		[".env"] = "dotenv",
		[".zshrc"] = "zsh",
		[".zprofile"] = "zsh",
	},
	pattern = {
		["%.env%..+"] = "dotenv",
	},
})

-- ============================================================================
-- FileType-specific Indentation & Syntax Settings
-- ============================================================================
vim.api.nvim_create_autocmd("FileType", {
	pattern = { "cfc", "cfm", "javascriptreact" },
	callback = function()
		vim.opt_local.cindent = true
		vim.opt_local.expandtab = true
		vim.opt_local.shiftwidth = 4
		vim.opt_local.tabstop = 4
	end,
})
