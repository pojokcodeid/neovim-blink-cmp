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

vim.api.nvim_create_user_command("ActivateRest", function()
	if editor.set_table_value("pcode.extras", "rest", true) then
		vim.notify("REST diaktifkan", vim.log.levels.INFO)
	else
		vim.notify("REST sudah aktif / tidak ditemukan", vim.log.levels.WARN)
	end
end, {})

vim.api.nvim_create_user_command("DeactivateRest", function()
	if editor.set_table_value("pcode.extras", "rest", false) then
		vim.notify("REST dimatikan", vim.log.levels.INFO)
	else
		vim.notify("REST sudah mati / tidak ditemukan", vim.log.levels.WARN)
	end
end, {})

vim.api.nvim_create_user_command("ToggleRest", function()
	local state = editor.toggle_table_value("pcode.extras", "rest")

	if state == true then
		vim.notify("REST activated", vim.log.levels.INFO, {
			title = "pcode.extras",
		})
	elseif state == false then
		vim.notify("REST deactivated", vim.log.levels.WARN, {
			title = "pcode.extras",
		})
	else
		vim.notify("Key 'rest' tidak ditemukan", vim.log.levels.ERROR, {
			title = "pcode.extras",
		})
	end
end, {})

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
		vim.notify("Gunakan: :Theme <theme> <variant>", vim.log.levels.WARN)
		return
	end

	local key = args[1]
	local value = table.concat(args, " ", 2)

	if editor.replace_theme(key, value) then
		vim.notify(("Theme diset: %s = %s"):format(key, value), vim.log.levels.INFO, { title = "pcode.themes" })
	else
		vim.notify("pcode.themes tidak ditemukan", vim.log.levels.ERROR)
	end
end, {
	nargs = "+",
	complete = theme_complete,
})
