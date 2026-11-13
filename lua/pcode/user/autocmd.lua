-- ============================================================================
-- Autocommands & Custom User Commands
-- ============================================================================
local api = vim.api
local fn = vim.fn
local levels = vim.log.levels

--- Helper membuat augroup baru yang di-clear otomatis
local function augroup(name)
	return api.nvim_create_augroup(name, { clear = true })
end

local autocmd = api.nvim_create_autocmd

-- ============================================================================
-- 1. General Editor Autocommands
-- ============================================================================
local general = augroup("_general_settings")

-- Quickfix tidak ditampilkan di buffer list
autocmd("FileType", {
	group = general,
	pattern = "qf",
	callback = function()
		vim.opt_local.buflisted = false
	end,
})

-- Aktifkan line wrap & spell checking untuk commit git dan markdown
autocmd("FileType", {
	group = augroup("_wrap_spell"),
	pattern = { "gitcommit", "markdown" },
	callback = function()
		vim.opt_local.wrap = true
		vim.opt_local.spell = true
	end,
})

-- Samakan proporsi ukuran split windows saat Neovim di-resize
autocmd("VimResized", {
	group = augroup("_auto_resize"),
	command = "tabdo wincmd =",
})

-- Tab size 4 untuk JavaScript, TypeScript, dan Go
autocmd("FileType", {
	group = augroup("_tabsize"),
	pattern = { "javascript", "typescript", "go" },
	callback = function()
		vim.opt_local.tabstop = 4
		vim.opt_local.shiftwidth = 4
	end,
})

-- Highlight teks saat di-yank (copy)
autocmd("TextYankPost", {
	group = augroup("YankHighlight"),
	callback = function()
		(vim.hl or vim.highlight).on_yank({ higroup = "IncSearch", timeout = 300 })
	end,
})

-- Buat direktori induk otomatis jika belum ada sebelum file disimpan
autocmd("BufWritePre", {
	group = augroup("BWCCreateDir"),
	callback = function(args)
		if vim.bo[args.buf].buftype ~= "" or args.match:match("^%w+://") then
			return
		end
		fn.mkdir(fn.fnamemodify(args.match, ":h"), "p")
	end,
})

-- Nonaktifkan CTRL+SHIFT+Drag Mouse yang tidak disengaja
for _, key in ipairs({ "<C-S-LeftMouse>", "<C-S-LeftDrag>", "<C-S-LeftRelease>" }) do
	vim.keymap.set("", key, "<Nop>", { silent = true })
end

-- ============================================================================
-- 2. Alpha Dashboard
-- ============================================================================
-- Sembunyikan tabline saat Alpha dashboard aktif, kembalikan setelah ditutup
autocmd("User", {
	group = augroup("_alpha"),
	pattern = "AlphaReady",
	callback = function()
		vim.o.showtabline = 0
		autocmd("BufUnload", {
			buffer = api.nvim_get_current_buf(),
			once = true,
			callback = function()
				vim.o.showtabline = 2
			end,
		})
	end,
})

-- ============================================================================
-- 3. Terminal Buffer & Workflow
-- ============================================================================
local term_group = augroup("neovim_terminal")

local function setup_terminal_buffer()
	vim.cmd("startinsert")
	vim.opt_local.number = false
	vim.opt_local.relativenumber = false
	vim.keymap.set("n", "<C-c>", "i<C-c>", { buffer = true })
end

autocmd("TermOpen", { group = term_group, callback = setup_terminal_buffer })
autocmd("FileType", { group = term_group, pattern = "checkhealth", callback = setup_terminal_buffer })

-- Refresh nvim-tree otomatis setelah Lazygit ditutup
autocmd("TermClose", {
	group = augroup("_lazygit_refresh"),
	pattern = "*lazygit*",
	callback = function()
		local ok, tree_api = pcall(require, "nvim-tree.api")
		if ok and tree_api.tree.is_visible() then
			vim.defer_fn(tree_api.tree.reload, 100)
		end
	end,
})

-- ============================================================================
-- 4. Cursor Management
-- ============================================================================
vim.opt.guicursor = {
	"n-v:block",
	"i-ci-ve-c:ver25",
	"r-cr:hor20",
	"o:hor50",
	"a:blinkwait700-blinkoff400-blinkon250",
	"sm:block-blinkwait175-blinkoff150-blinkon175",
}

-- Kembalikan kursor ke bentuk beam saat keluar dari Neovim
autocmd("ExitPre", {
	group = augroup("Exit"),
	desc = "Kembalikan bentuk cursor ke beam saat keluar dari Neovim.",
	callback = function()
		vim.o.guicursor = "n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50,"
			.. "a:blinkwait700-blinkoff400-blinkon250-Cursor/lCursor,"
			.. "sm:block-blinkwait175-blinkoff150-blinkon175,a:ver90"
	end,
})

-- ============================================================================
-- 5. Diagnostic Error Line Highlighting
-- ============================================================================
local function hex_to_rgb(hex)
	hex = hex:gsub("#", "")
	return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
end

--- Campur dua warna hex dengan alpha
local function blend(foreground, background, alpha)
	alpha = type(alpha) == "string" and (tonumber(alpha, 16) / 255) or alpha
	local fr, fg, fb = hex_to_rgb(foreground)
	local br, bg, bb = hex_to_rgb(background)

	local function mix(f, b)
		return math.floor(alpha * f + (1 - alpha) * b + 0.5)
	end

	return string.format("#%02x%02x%02x", mix(fr, br), mix(fg, bg), mix(fb, bb))
end

local ERROR_BG, ERROR_FG, ERROR_ALPHA = "#282a36", "#ff5555", 0.05
local error_ns = api.nvim_create_namespace("error_line_hl")

local function set_error_hl()
	api.nvim_set_hl(0, "ErrorLineBg", { bg = blend(ERROR_FG, ERROR_BG, ERROR_ALPHA) })
end
set_error_hl()

local diag_group = augroup("_error_line_hl")
autocmd("ColorScheme", { group = diag_group, callback = set_error_hl })

autocmd("DiagnosticChanged", {
	group = diag_group,
	callback = function(args)
		local bufnr = args.buf
		if not api.nvim_buf_is_valid(bufnr) then
			return
		end
		api.nvim_buf_clear_namespace(bufnr, error_ns, 0, -1)

		for _, d in ipairs(vim.diagnostic.get(bufnr, { severity = vim.diagnostic.severity.ERROR })) do
			for lnum = d.lnum, d.end_lnum or d.lnum do
				pcall(api.nvim_buf_set_extmark, bufnr, error_ns, lnum, 0, {
					line_hl_group = "ErrorLineBg",
					priority = 10,
				})
			end
		end
	end,
})

-- Quickfix dari popup menu
autocmd("VimEnter", {
	group = augroup("_popup_diagnostics"),
	callback = function()
		vim.cmd([[
			silent! aunmenu PopUp.Show\ All\ Diagnostics
			anoremenu 500 PopUp.Show\ All\ Diagnostics <Cmd>lua vim.diagnostic.setqflist({ open = false }); vim.cmd("belowright copen")<CR>
		]])
	end,
})

-- ============================================================================
-- 6. User Commands: Treesitter
-- ============================================================================
api.nvim_create_user_command("TSIsInstalled", function()
	local parsers = require("nvim-treesitter.info").installed_parsers()
	table.sort(parsers)

	vim.ui.select(parsers, {
		prompt = "Uninstall Treesitter parser:",
		format_item = function(parser)
			return "[✓] " .. parser
		end,
	}, function(choice)
		if choice then
			vim.cmd("TSUninstall " .. choice)
		end
	end)
end, { desc = "Pilih parser Treesitter yang terinstal untuk di-uninstall" })

-- ============================================================================
-- 7. User Commands: PCode Config, Plugins, Themes
-- ============================================================================
local editor = require("pcode.core.default_editor")
local registry = require("pcode.core.theme_registry")

--- Kumpulkan "<label> => <key>" dari tbl
local function collect(tbl, label, enabled, strict)
	local out = {}
	for key, value in pairs(tbl) do
		local match
		if strict then
			match = (value == enabled)
		else
			match = (value and true or false) == enabled
		end
		if match then
			out[#out + 1] = label .. " => " .. key
		end
	end
	table.sort(out)
	return out
end

local function feature_candidates(enabled)
	local conf = _G.pcode or {}
	local items = collect(conf.extras or {}, "Extras", enabled)
	vim.list_extend(items, collect(conf, "Conf", enabled, true))
	vim.list_extend(items, collect(conf.lang or {}, "Lang", enabled))
	return items
end

local function clean_feature(arg)
	return vim.trim((arg:gsub("^%a+%s*=>%s*", "")))
end

local FEATURE_MESSAGES = {
	[true] = { conf = "Config activated", extra = "Extra activated", lang = "Lang activated" },
	[false] = { conf = "Config inactive", extra = "Extra removed", lang = "Lang removed" },
}

local function set_feature(fitur, enabled)
	if fitur == "" then
		vim.notify("Gunakan :" .. (enabled and "PCodeAdd" or "PCodeRemove") .. " <nama_plugin>", levels.WARN)
		return
	end

	local msg = FEATURE_MESSAGES[enabled]
	local targets = {
		{
			msg.conf,
			function()
				return editor.set_dot_value("pcode." .. fitur, enabled)
			end,
		},
		{
			msg.extra,
			function()
				return editor.set_table_value("pcode.extras", fitur, enabled)
			end,
		},
		{
			msg.lang,
			function()
				return editor.set_table_value("pcode.lang", fitur, enabled)
			end,
		},
	}

	for _, target in ipairs(targets) do
		if target[2]() then
			vim.notify(target[1] .. ": " .. fitur .. "\n Please restart Neovim", levels.INFO, { title = "pcode" })
			return
		end
	end

	vim.notify("Fitur tidak ditemukan: " .. fitur, levels.ERROR, { title = "pcode" })
end

api.nvim_create_user_command("PCodeAdd", function(opts)
	set_feature(clean_feature(opts.args), true)
end, {
	nargs = 1,
	desc = "Aktifkan plugin/bahasa/fitur di default.lua",
	complete = function()
		return feature_candidates(false)
	end,
})

api.nvim_create_user_command("PCodeRemove", function(opts)
	set_feature(clean_feature(opts.args), false)
end, {
	nargs = 1,
	desc = "Nonaktifkan plugin/bahasa/fitur di default.lua",
	complete = function()
		return feature_candidates(true)
	end,
})

local function theme_complete(_, cmdline)
	local args = vim.split(cmdline, "%s+")
	local result = {}

	if #args >= 3 then
		local key, prefix = args[2], args[3]:lower()
		for _, variant in ipairs(registry.themes[key] or {}) do
			if variant:lower():find(prefix, 1, true) then
				result[#result + 1] = key .. " " .. variant
			end
		end
		return result
	end

	local keys = vim.tbl_keys(registry.themes)
	table.sort(keys)
	for _, key in ipairs(keys) do
		for _, variant in ipairs(registry.themes[key]) do
			result[#result + 1] = key .. " " .. variant
		end
	end
	return result
end

api.nvim_create_user_command("Theme", function(opts)
	local args = vim.split(opts.args, "%s+", { trimempty = true })
	if #args < 2 then
		vim.notify("Gunakan: :Theme <theme> <variant>", levels.WARN)
		return
	end

	local key = args[1]
	local value = table.concat(args, " ", 2)

	if editor.replace_theme(key, value) then
		vim.notify(("Theme set: %s = %s"):format(key, value), levels.INFO, { title = "pcode.themes" })
	else
		vim.notify("pcode.themes tidak ditemukan", levels.ERROR)
	end
end, {
	nargs = "+",
	desc = "Ganti dan simpan tema aktif ke default.lua",
	complete = theme_complete,
})

api.nvim_create_user_command("PCodeConfig", function()
	require("pcode.ui.pcode_dashboard").open()
end, { desc = "Buka dashboard konfigurasi PCode" })

-- ============================================================================
-- 8. User Commands: LSP Inspection & Status
-- ============================================================================
local function get_clients(bufnr)
	local get = vim.lsp.get_clients or vim.lsp.get_active_clients
	return get({ bufnr = bufnr })
end

local function supported_features(caps, list)
	local out = {}
	for _, item in ipairs(list) do
		if caps[item[1]] then
			out[#out + 1] = item[2]
		end
	end
	return out
end

local function diagnostic_counts(bufnr)
	local counts = { ERROR = 0, WARN = 0, INFO = 0, HINT = 0 }
	local diagnostics = vim.diagnostic.get(bufnr)
	for _, d in ipairs(diagnostics) do
		local name = vim.diagnostic.severity[d.severity]
		counts[name] = counts[name] + 1
	end
	return counts, #diagnostics
end

local STATUS_FEATURES = {
	{ "completionProvider", "completion" },
	{ "hoverProvider", "hover" },
	{ "definitionProvider", "definition" },
	{ "referencesProvider", "references" },
	{ "renameProvider", "rename" },
	{ "codeActionProvider", "code_action" },
	{ "documentFormattingProvider", "formatting" },
}

local KEY_FEATURES = {
	{ "completionProvider", "completion" },
	{ "hoverProvider", "hover" },
	{ "definitionProvider", "definition" },
	{ "documentFormattingProvider", "formatting" },
	{ "codeActionProvider", "code_action" },
}

local ALL_CAPABILITIES = {
	{ "Completion", "completionProvider" },
	{ "Hover", "hoverProvider" },
	{ "Signature Help", "signatureHelpProvider" },
	{ "Go to Definition", "definitionProvider" },
	{ "Go to Declaration", "declarationProvider" },
	{ "Go to Implementation", "implementationProvider" },
	{ "Go to Type Definition", "typeDefinitionProvider" },
	{ "Find References", "referencesProvider" },
	{ "Document Highlight", "documentHighlightProvider" },
	{ "Document Symbol", "documentSymbolProvider" },
	{ "Workspace Symbol", "workspaceSymbolProvider" },
	{ "Code Action", "codeActionProvider" },
	{ "Code Lens", "codeLensProvider" },
	{ "Document Formatting", "documentFormattingProvider" },
	{ "Document Range Formatting", "documentRangeFormattingProvider" },
	{ "Rename", "renameProvider" },
	{ "Folding Range", "foldingRangeProvider" },
	{ "Selection Range", "selectionRangeProvider" },
}

api.nvim_create_user_command("LspStatus", function()
	local bufnr = api.nvim_get_current_buf()
	local clients = get_clients(bufnr)

	if #clients == 0 then
		print("󰅚 No LSP clients attached")
		return
	end

	print("󰒋 LSP Status for buffer " .. bufnr .. ":")
	print("─────────────────────────────────")

	for i, client in ipairs(clients) do
		print(string.format("󰌘 Client %d: %s (ID: %d)", i, client.name, client.id))
		print("  Root: " .. (client.config.root_dir or "N/A"))
		print("  Filetypes: " .. table.concat(client.config.filetypes or {}, ", "))
		print("  Features: " .. table.concat(supported_features(client.server_capabilities, STATUS_FEATURES), ", "))
		print("")
	end
end, { desc = "Tampilkan status detail LSP" })

api.nvim_create_user_command("LspCapabilities", function()
	local clients = get_clients(api.nvim_get_current_buf())

	if #clients == 0 then
		print("No LSP clients attached")
		return
	end

	for _, client in ipairs(clients) do
		print("Capabilities for " .. client.name .. ":")
		for _, cap in ipairs(ALL_CAPABILITIES) do
			print(string.format("  %s %s", client.server_capabilities[cap[2]] and "✓" or "✗", cap[1]))
		end
		print("")
	end
end, { desc = "Tampilkan daftar kapabilitas server LSP" })

api.nvim_create_user_command("LspDiagnostics", function()
	local counts, total = diagnostic_counts(api.nvim_get_current_buf())

	print("󰒡 Diagnostics for current buffer:")
	print("  Errors: " .. counts.ERROR)
	print("  Warnings: " .. counts.WARN)
	print("  Info: " .. counts.INFO)
	print("  Hints: " .. counts.HINT)
	print("  Total: " .. total)
end, { desc = "Tampilkan ringkasan diagnostik LSP" })

api.nvim_create_user_command("LspInfo", function()
	local bufnr = api.nvim_get_current_buf()
	local clients = get_clients(bufnr)

	print("═══════════════════════════════════")
	print("           LSP INFORMATION          ")
	print("═══════════════════════════════════")
	print("")
	print("󰈙 Language client log: " .. vim.lsp.get_log_path())
	print("󰈔 Detected filetype: " .. vim.bo.filetype)
	print("󰈮 Buffer: " .. bufnr)
	print("󰈔 Root directory: " .. fn.getcwd())
	print("")

	if #clients == 0 then
		print("󰅚 No LSP clients attached to buffer " .. bufnr)
		print("")
		print("Kemungkinan penyebab:")
		print("  • Belum ada language server terinstal untuk " .. vim.bo.filetype)
		print("  • Language server belum dikonfigurasi")
		print("  • Bukan di dalam direktori root project")
		print("  • Filetype belum dikenali")
		return
	end

	print("󰒋 LSP clients attached to buffer " .. bufnr .. ":")
	print("─────────────────────────────────")

	for i, client in ipairs(clients) do
		print(string.format("󰌘 Client %d: %s", i, client.name))
		print("  ID: " .. client.id)
		print("  Root dir: " .. (client.config.root_dir or "Not set"))
		print("  Command: " .. table.concat(client.config.cmd or {}, " "))
		print("  Filetypes: " .. table.concat(client.config.filetypes or {}, ", "))
		print("  Status: " .. (client:is_stopped() and "󰅚 Stopped" or "󰄬 Running"))

		if client.workspace_folders and #client.workspace_folders > 0 then
			print("  Workspace folders:")
			for _, folder in ipairs(client.workspace_folders) do
				print("    • " .. folder.name)
			end
		end

		print("  Attached buffers: " .. vim.tbl_count(client.attached_buffers or {}))

		local features = supported_features(client.server_capabilities, KEY_FEATURES)
		if #features > 0 then
			print("  Key features: " .. table.concat(features, ", "))
		end
		print("")
	end

	local counts, total = diagnostic_counts(bufnr)
	if total > 0 then
		print("󰒡 Diagnostics Summary:")
		print("  󰅚 Errors: " .. counts.ERROR)
		print("  󰀪 Warnings: " .. counts.WARN)
		print("  󰋽 Info: " .. counts.INFO)
		print("  󰌶 Hints: " .. counts.HINT)
		print("  Total: " .. total)
	else
		print("󰄬 No diagnostics")
	end

	print("")
	print("Gunakan :LspLog untuk melihat log detail")
	print("Gunakan :LspCapabilities untuk daftar lengkap kapabilitas")
end, { desc = "Tampilkan informasi komprehensif LSP" })

-- ============================================================================
-- 9. User Commands: CFLint
-- ============================================================================
local ANSI_PATTERN = "\27%[[%d;]*m"
local CFLINT_LINE = "^%s*(%u+):%s*([%u_]+),%s*(.-)%s*%[(%d+),(%d+)%]%s*$"

local function parse_cflint(lines, file)
	local raw = table.concat(lines, "\n"):gsub(ANSI_PATTERN, "")
	local items = {}

	for line in raw:gmatch("[^\r\n]+") do
		local sev, code, msg, lnum, col = line:match(CFLINT_LINE)
		if sev then
			items[#items + 1] = {
				filename = file,
				lnum = tonumber(lnum),
				col = tonumber(col),
				text = string.format("[%s] %s (%s)", sev, msg, code),
				type = "E",
			}
		end
	end

	return items
end

local function cflint_check()
	local file = api.nvim_buf_get_name(0)
	if file == "" then
		vim.notify("Buffer belum memiliki file yang tersimpan.", levels.WARN)
		return
	end
	if fn.executable("box") == 0 then
		vim.notify("Perintah `box` tidak ditemukan di PATH.", levels.ERROR)
		return
	end

	local filename = fn.fnamemodify(file, ":t")
	local output = {}
	local function on_output(_, data)
		if data then
			vim.list_extend(output, data)
		end
	end

	local job_id = fn.jobstart({ "box", "cflint", "pattern=" .. filename, "reportLevel=ERROR" }, {
		cwd = fn.fnamemodify(file, ":h"),
		stdin = "null",
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = on_output,
		on_stderr = on_output,
		on_exit = function()
			local items = parse_cflint(output, file)
			vim.schedule(function()
				fn.setqflist({}, "r", { title = "CFLint - " .. filename, items = items })
				if #items > 0 then
					vim.cmd("belowright copen")
				else
					vim.notify("CFLint: tidak ada error ditemukan.", levels.INFO)
				end
			end)
		end,
	})

	if job_id <= 0 then
		vim.notify("Gagal menjalankan job CFLint! job_id=" .. job_id, levels.ERROR)
		return
	end

	vim.notify("Menjalankan CFLint...", levels.INFO)
end

api.nvim_create_user_command("CflintCheck", cflint_check, { desc = "Jalankan box cflint untuk file aktif" })

--- reload http file ketika di edit
---
vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave" }, {
	group = general,
	pattern = "*.http",
	callback = function(ev)
		pcall(function()
			vim.treesitter.get_parser(ev.buf, "http"):parse(true)
		end)
	end,
})
