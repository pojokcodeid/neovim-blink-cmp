local api = vim.api

-- Pengaturan umum
api.nvim_create_augroup("_general_settings", { clear = true })

api.nvim_create_autocmd("FileType", {
	group = "_general_settings",
	pattern = "qf",
	command = "set nobuflisted", -- Mengatur buffer agar tidak terdaftar di buffer list
})

-- Pengaturan Git
api.nvim_create_augroup("_git", { clear = true }) -- Membuat grup autocommand untuk git
api.nvim_create_autocmd("FileType", {
	group = "_git",
	pattern = "gitcommit",
	command = "setlocal wrap spell", -- Mengatur wrap dan spell check untuk file git commit
})

-- Pengaturan Markdown
api.nvim_create_augroup("_markdown", { clear = true }) -- Membuat grup autocommand untuk markdown
api.nvim_create_autocmd("FileType", {
	group = "_markdown",
	pattern = "markdown",
	command = "setlocal wrap spell", -- Mengatur wrap dan spell check untuk file markdown
})

-- Pengaturan Auto Resize
api.nvim_create_augroup("_auto_resize", { clear = true }) -- Membuat grup autocommand untuk auto resize
api.nvim_create_autocmd("VimResized", {
	group = "_auto_resize",
	command = "tabdo wincmd =", -- Menyesuaikan ukuran window saat Vim di-resize
})

-- Pengaturan Alpha
api.nvim_create_augroup("_alpha", { clear = true }) -- Membuat grup autocommand untuk alpha
api.nvim_create_autocmd("User", {
	group = "_alpha",
	pattern = "AlphaReady",
	command = "set showtabline=0 | autocmd BufUnload <buffer> set showtabline=2", -- Menyembunyikan tabline saat alpha siap dan menampilkan kembali saat buffer di-unload
})

-- Pengaturan Terminal
api.nvim_create_augroup("neovim_terminal", { clear = true }) -- Membuat grup autocommand untuk terminal
api.nvim_create_autocmd("TermOpen", {
	group = "neovim_terminal",
	command = "startinsert | set nonumber norelativenumber | nnoremap <buffer> <C-c> i<C-c>", -- Memasuki mode insert secara otomatis dan menonaktifkan nomor baris di buffer terminal
})
api.nvim_create_autocmd("FileType", {
	group = "neovim_terminal",
	pattern = "checkhealth",
	command = "startinsert | set nonumber norelativenumber | nnoremap <buffer> <C-c> i<C-c>", -- Memasuki mode insert secara otomatis dan menonaktifkan nomor baris di buffer terminal
})

-- Fungsi untuk Membuat Direktori yang Tidak Ada pada BufWrite
local function MkNonExDir(file, buf)
	if vim.fn.empty(vim.fn.getbufvar(buf, "&buftype")) == 1 and not string.match(file, "^%w+://") then
		local dir = vim.fn.fnamemodify(file, ":h")
		if vim.fn.isdirectory(dir) == 0 then
			vim.fn.mkdir(dir, "p") -- Membuat direktori jika tidak ada
		end
	end
end

api.nvim_create_augroup("BWCCreateDir", { clear = true }) -- Membuat grup autocommand untuk membuat direktori
api.nvim_create_autocmd("BufWritePre", {
	group = "BWCCreateDir",
	callback = function(_)
		MkNonExDir(vim.fn.expand("<afile>"), vim.fn.expand("<abuf>")) -- Memanggil fungsi untuk membuat direktori yang tidak ada sebelum menyimpan buffer
	end,
})

-- config cursor
vim.opt.guicursor = {
	"n-v:block", -- Normal, Visual, Command mode: block cursor
	"i-ci-ve-c:ver25", -- Insert, Command-line Insert, Visual mode: vertical bar cursor
	"r-cr:hor20", -- Replace, Command-line Replace mode: horizontal bar cursor
	"o:hor50", -- Operator-pending mode: horizontal bar cursor
	"a:blinkwait700-blinkoff400-blinkon250", -- Blinking settings
	"sm:block-blinkwait175-blinkoff150-blinkon175", -- Select mode: block cursor with blinking
}

vim.api.nvim_create_autocmd("ExitPre", {
	group = vim.api.nvim_create_augroup("Exit", { clear = true }),
	command = "set guicursor=n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50,a:blinkwait700-blinkoff400-blinkon250-Cursor/lCursor,sm:block-blinkwait175-blinkoff150-blinkon175,a:ver90",
	desc = "Set cursor back to beam when leaving Neovim.",
})

vim.api.nvim_create_user_command("TSIsInstalled", function()
	local parsers = require("nvim-treesitter.info").installed_parsers()
	table.sort(parsers)
	local choices = {}
	local lookup = {}

	for _, parser in ipairs(parsers) do
		local label = "[✓] " .. parser
		table.insert(choices, label)
		lookup[label] = parser
	end

	vim.ui.select(choices, {
		prompt = "Uninstall Treesitter",
	}, function(choice)
		if choice then
			local parser_name = lookup[choice]
			if parser_name then
				vim.cmd("TSUninstall " .. parser_name)
			end
		end
	end)
end, {})

-- custom user command
local editor = require("pcode.core.default_editor")
local registry = require("pcode.core.theme_registry")

-- Fungsi untuk menggabungkan dua table
local function gabungTable(a, b)
	local hasil = {}
	-- masukkan isi table pertama
	for i = 1, #a do
		table.insert(hasil, a[i])
	end
	-- masukkan isi table kedua
	for i = 1, #b do
		table.insert(hasil, b[i])
	end
	return hasil
end

-- extras data
local noinstalextras = {}
local instaledextras = {}
local extras = pcode.extras or {}
for key, value in pairs(extras) do
	if value then
		table.insert(instaledextras, "Extras => " .. key)
	else
		table.insert(noinstalextras, "Extras => " .. key)
	end
end
table.sort(noinstalextras)
table.sort(instaledextras)
-- end exptras

-- lang data
local noinstallang = {}
local instaledlang = {}
local langs = pcode.lang or {}
for key, value in pairs(langs) do
	if value then
		table.insert(instaledlang, "Lang => " .. key)
	else
		table.insert(noinstallang, "Lang => " .. key)
	end
end
table.sort(noinstallang)
table.sort(instaledlang)

-- activate data
local noactivateds = {}
local activateds = {}
local activate = pcode or {}
for key, value in pairs(activate) do
	if value == true then
		table.insert(activateds, "Conf => " .. key)
	elseif value == false then
		table.insert(noactivateds, "Conf => " .. key)
	end
end
table.sort(noactivateds)
table.sort(activateds)

local gabungan = gabungTable(noinstalextras, noactivateds)
gabungan = gabungTable(gabungan, noinstallang)

local gabungInstalled = gabungTable(instaledextras, activateds)
gabungInstalled = gabungTable(gabungInstalled, instaledlang)

-- set extras user command
vim.api.nvim_create_user_command("PCodeAdd", function(opts)
	local groupTabel = "pcode"
	local groupTabel2 = "pcode.extras"
	local groupTabel3 = "pcode.lang"
	local fitur = opts.args
	fitur = string.gsub(fitur, "Lang%s*=>%s*", "")
	fitur = string.gsub(fitur, "Extras%s*=>%s*", "")
	fitur = string.gsub(fitur, "Conf%s*=>%s*", "")

	if fitur == "" then
		vim.notify("Gunakan :PCodeAdd <nama_plugin>", vim.log.levels.WARN)
		return
	end

	if editor.set_dot_value(groupTabel .. "." .. fitur, true) then
		vim.notify(
			"Config activated: " .. fitur .. "\n Please restart Neovim",
			vim.log.levels.INFO,
			{ title = groupTabel }
		)
	elseif editor.set_table_value(groupTabel2, fitur, true) then
		vim.notify(
			"Extra activated: " .. fitur .. "\n Please restart Neovim",
			vim.log.levels.INFO,
			{ title = groupTabel }
		)
	elseif editor.set_table_value(groupTabel3, fitur, true) then
		vim.notify(
			"Lang activated: " .. fitur .. "\n Please restart Neovim",
			vim.log.levels.INFO,
			{ title = groupTabel }
		)
	else
		vim.notify("Fitur tidak ditemukan: " .. fitur, vim.log.levels.ERROR, { title = groupTabel })
	end
end, {
	nargs = 1,
	complete = function()
		-- return noactivateds
		return gabungan
	end,
})

vim.api.nvim_create_user_command("PCodeRemove", function(opts)
	local groupTabel = "pcode"
	local groupTabel2 = "pcode.extras"
	local groupTabel3 = "pcode.lang"
	local fitur = opts.args
	fitur = string.gsub(fitur, "Lang%s*=>%s*", "")
	fitur = string.gsub(fitur, "Extras%s*=>%s*", "")
	fitur = string.gsub(fitur, "Conf%s*=>%s*", "")

	if fitur == "" then
		vim.notify("Gunakan :PCodeAdd <nama_plugin>", vim.log.levels.WARN)
		return
	end

	if editor.set_dot_value(groupTabel .. "." .. fitur, false) then
		vim.notify(
			"Config inactive: " .. fitur .. "\n Please restart Neovim",
			vim.log.levels.INFO,
			{ title = groupTabel }
		)
	elseif editor.set_table_value(groupTabel2, fitur, false) then
		vim.notify(
			"Extra removed: " .. fitur .. "\n Please restart Neovim",
			vim.log.levels.INFO,
			{ title = groupTabel }
		)
	elseif editor.set_table_value(groupTabel3, fitur, false) then
		vim.notify("Lang removed: " .. fitur .. "\n Please restart Neovim", vim.log.levels.INFO, { title = groupTabel })
	else
		vim.notify("Fitur tidak ditemukan: " .. fitur, vim.log.levels.ERROR, { title = groupTabel })
	end
end, {
	nargs = 1,
	complete = function()
		return gabungInstalled
	end,
})
-- end activate

local function theme_complete(_, cmdline)
	local args = vim.split(cmdline, "%s+")

	local result = {}

	-- :Theme evatheme Eva
	if #args >= 3 then
		local key = args[2]
		local prefix = args[3] or ""

		for _, variant in ipairs(registry.themes[key] or {}) do
			if variant:lower():find(prefix:lower(), 1, true) then
				table.insert(result, key .. " " .. variant)
			end
		end
		return result
	end

	-- :Theme <TAB>
	for key, variants in pairs(registry.themes) do
		for _, variant in ipairs(variants) do
			table.insert(result, key .. " " .. variant)
		end
	end

	return result
end

vim.api.nvim_create_user_command("Theme", function(opts)
	local args = vim.split(opts.args, "%s+", { trimempty = true })

	if #args < 2 then
		vim.notify("Use: :Theme <theme> <variant>", vim.log.levels.WARN)
		return
	end

	local key = args[1]
	local value = table.concat(args, " ", 2)

	if editor.replace_theme(key, value) then
		vim.notify(("Theme set: %s = %s"):format(key, value), vim.log.levels.INFO, { title = "pcode.themes" })
	else
		vim.notify("pcode.themes not found", vim.log.levels.ERROR)
	end
end, {
	nargs = "+",
	complete = theme_complete,
})

vim.api.nvim_create_user_command("PCodeConfig", function()
	require("pcode.ui.pcode_dashboard").open()
end, {})

-- Nonaktifkan kombinasi CTRL+SHIFT+Drag Mouse
vim.keymap.set("", "<C-S-LeftMouse>", "<Nop>", { noremap = true, silent = true })
vim.keymap.set("", "<C-S-LeftDrag>", "<Nop>", { noremap = true, silent = true })
vim.keymap.set("", "<C-S-LeftRelease>", "<Nop>", { noremap = true, silent = true })

-- set tabsize 4 if file type php
vim.api.nvim_create_autocmd("FileType", {
	pattern = { "javascript", "typescript" },
	callback = function()
		vim.opt.tabstop = 4
		vim.opt.shiftwidth = 4
	end,
})
