-- Hapus alert / print sebelumnya

-- Force cindent & indentexpr khusus buffer CFML
vim.bo.cindent = true
vim.bo.smartindent = false
vim.bo.indentexpr = "cindent(v:lnum)"

-- Formatting tab/spasi
vim.bo.expandtab = true
vim.bo.shiftwidth = 4
vim.bo.tabstop = 4

vim.bo.autoindent = true
vim.bo.indentexpr = ""
-- hapus trigger '0#' (yang bikin '#' dipaksa ke kolom 0) dari indentkeys
vim.bo.cinkeys = vim.bo.cinkeys:gsub(",?0#", "")

-- Align kurung kurawal { } & pemicu kata kunci
vim.bo.cinoptions = "{0,}0,j1,J1"
vim.bo.cinwords = "component,function,if,else,for,while,switch,try,catch"

-- config for comment string
local ext = vim.fn.expand("%:e")

if ext == "cfm" then
	vim.bo.commentstring = "<!--- %s --->"
else
	vim.bo.commentstring = "// %s" -- cfc, sfc
end

local comment_ft = require("Comment.ft")

-- Daftarkan commentstring linewise & blockwise khusus per filetype
-- Comment.ft.set(filetype, { linewise, blockwise })
comment_ft.set("cfml", { "// %s", "/* %s */" }) -- default untuk .cfc/.sfc

require("Comment").setup({
	pre_hook = function(ctx)
		local ext = vim.fn.expand("%:e")
		local U = require("Comment.utils")

		if ext == "cfm" then
			-- .cfm selalu pakai gaya tag, linewise & blockwise sama saja
			return "<!--- %s --->"
		end

		-- .cfc / .sfc → cfscript
		if ctx.ctype == U.ctype.linewise then
			return "// %s"
		else
			return "/* %s */"
		end
	end,
})

-- config for auto close tag
------------------------------------------------------------
-- Daftar tag yang butuh pasangan penutup (whitelist)
-- Tag self-closing (cfset, cfparam, cfinclude, dll) SENGAJA tidak
-- dimasukkan supaya tidak ikut auto-close.
------------------------------------------------------------
local closing_tags = {
	cfif = true,
	cfelseif = true,
	cfelse = true,
	cfloop = true,
	cfoutput = true,
	cftry = true,
	cfcatch = true,
	cffinally = true,
	cfswitch = true,
	cfcase = true,
	cfdefaultcase = true,
	cffunction = true,
	cfcomponent = true,
	cflock = true,
	cftransaction = true,
	cfsavecontent = true,
	cfquery = true,
	cfstoredproc = true,
	cfscript = true,
	cfmail = true,
	cfhttp = true,
	cfthread = true,
	cfzip = true,
	cfpdf = true,
	cfdocument = true,
}

------------------------------------------------------------
-- Auto-close: ketik ">" setelah "<cfif ..." -> jadi "<cfif ...></cfif>"
------------------------------------------------------------
local function cfml_auto_close_on_gt()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	local line = vim.api.nvim_get_current_line()
	local before = line:sub(1, col)

	-- skip kalau tag ditulis self-closing, misal: <cfif ... />
	if before:match("/%s*$") then
		vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, { ">" })
		vim.api.nvim_win_set_cursor(0, { row, col + 1 })
		return
	end

	local tagname = before:match("<(%a[%w_]*)[^<>]*$")

	vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, { ">" })
	vim.api.nvim_win_set_cursor(0, { row, col + 1 })

	if tagname and closing_tags[tagname:lower()] then
		local closing = "</" .. tagname .. ">"
		vim.api.nvim_buf_set_text(0, row - 1, col + 1, row - 1, col + 1, { closing })
		vim.api.nvim_win_set_cursor(0, { row, col + 1 })
	end
end

vim.keymap.set("i", ">", cfml_auto_close_on_gt, {
	buffer = true,
	desc = "Auto close CFML tag",
})

------------------------------------------------------------
-- Expand: Enter di antara tag pembuka & penutup -> jadi 3 baris
-- (untuk kasus lain, serahkan ke nvim-autopairs supaya behavior
--  expand {}, (), [] bawaan plugin tetap jalan)
------------------------------------------------------------
local function cfml_expand_on_cr()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	local line = vim.api.nvim_get_current_line()
	local before = line:sub(1, col)
	local after = line:sub(col + 1)

	local is_after_open_tag = before:match(">%s*$") ~= nil
	local closing_tagname = after:match("^</(%a[%w_]*)>")

	if is_after_open_tag and closing_tagname then
		local current_indent = line:match("^%s*") or ""
		local shiftwidth = vim.bo.shiftwidth > 0 and vim.bo.shiftwidth or vim.bo.tabstop
		local extra_indent
		if vim.bo.expandtab then
			extra_indent = string.rep(" ", shiftwidth)
		else
			extra_indent = "\t"
		end
		local middle_indent = current_indent .. extra_indent

		vim.api.nvim_buf_set_lines(0, row - 1, row, false, {
			before,
			middle_indent,
			current_indent .. after,
		})

		vim.api.nvim_win_set_cursor(0, { row + 1, #middle_indent })
	else
		local ok, npairs = pcall(require, "nvim-autopairs")
		if ok and npairs.autopairs_cr then
			vim.api.nvim_feedkeys(npairs.autopairs_cr(), "n", false)
		else
			local keys = vim.api.nvim_replace_termcodes("<CR>", true, false, true)
			vim.api.nvim_feedkeys(keys, "n", false)
		end
	end
end

vim.keymap.set("i", "<CR>", cfml_expand_on_cr, {
	buffer = true,
	desc = "Expand CFML tag block on Enter",
})

-- config ini untuk cflint
--[[
  rule exculde 

  1. // CFLINT-DISABL -> EMengabaikan Per-Baris Kode (Line Level) bisa diatasnya
    atau disampingnya 
  2. // CFLINT-DISABLE MISSING_VAR -> Mengabaikan Aturan Tertentu Sahaja (Rule Specific)/**
  3. Mengabaikan Satu Fungsi / Component (Function / File Level)

  /**
  * @cflint-ignore MISSING_VAR
  */
  public any function approve(required string RequestKey) {
      cfparam(name = "attresult", default = "");
      // ...
  }
  4. Mengabaikan Global via File Config .cflintrc
  
  {
    "excludes": [
      {
        "name": "MISSING_VAR"
      }
    ]
  }

]]
--
-- integrasi dengan nvim-lint
local lint = require("lint")

-- Helper untuk membaca & memuat aturan .cflintrc jika ada
local function get_excluded_rules_from_config(bufnr)
	local bufpath = vim.api.nvim_buf_get_name(bufnr)
	local root_dir = vim.fs.dirname(vim.fs.find(".cflintrc", { path = bufpath, upward = true })[1])

	if not root_dir then
		return {}
	end

	local config_file = root_dir .. "/.cflintrc"
	local f = io.open(config_file, "r")
	if not f then
		return {}
	end

	local content = f:read("*a")
	f:close()

	local ok, decoded = pcall(vim.json.decode, content)
	if not ok or not decoded or not decoded.excludes then
		return {}
	end

	local excluded = {}
	for _, item in ipairs(decoded.excludes) do
		if item.name then
			excluded[item.name] = true
		end
	end
	return excluded
end

-- Custom Linter CFLint
lint.linters.cflint = {
	cmd = "java",
	args = {
		"-jar",
		vim.fn.expand(
			"/Users/asepkomarudin/.CommandBox/cfml/modules/commandbox-cflint/lib/CFLint-1.5.0-all/CFLint-1.5.0-all.jar"
		),
		"-file",
		function()
			return vim.api.nvim_buf_get_name(0)
		end,
		"-json",
		"-stdout",
	},
	stdin = false,
	stream = "stdout",
	ignore_exitcode = true,
	parser = function(output, bufnr)
		if output == "" or output == nil then
			return {}
		end

		local ok, decoded = pcall(vim.json.decode, output)
		if not ok or not decoded or not decoded.issues then
			return {}
		end

		-- 1. Load rule yang di-exclude via file .cflintrc
		local config_excludes = get_excluded_rules_from_config(bufnr)

		-- 2. Ambil baris-baris kode di buffer Neovim
		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

		-- Helper untuk scan annotation @cflint-ignore / @cflint-disable ke atas dari suatu baris (untuk level fungsi)
		local function is_ignored_by_function_annotation(line_idx, rule_id)
			for i = line_idx, 1, -1 do
				local line = lines[i] or ""

				-- Berhenti scan ke atas jika sudah keluar dari block comment atau bertemu fungsi lain
				if line:find("^%s*function%s+") or line:find("^%s*public%s+") or line:find("^%s*private%s+") then
					if i < line_idx - 1 then
						-- Jika bertemu keyword function sebelum anotasi, batasi pencarian
					end
				end

				local annotation = line:match("@cflint%-ignore%s+([%w_]+)") or line:match("@cflint%-disable%s+([%w_]+)")

				if annotation then
					if annotation == rule_id or annotation == "ALL" then
						return true
					end
				end

				if line:find("@cflint%-ignore%s*$") or line:find("@cflint%-disable%s*$") then
					return true
				end

				-- Batasi scan maksimal 50 baris ke atas demi performa
				if (line_idx - i) > 50 then
					break
				end
			end
			return false
		end

		local diagnostics = {}

		for _, issue in ipairs(decoded.issues) do
			local rule_id = issue.id or ""

			-- Cek 1: Apakah di-exclude oleh global .cflintrc?
			if issue.severity == "ERROR" and not config_excludes[rule_id] then
				for _, location in ipairs(issue.locations or {}) do
					local line_idx = location.line or 1
					local current_line = lines[line_idx] or ""
					local prev_line = lines[line_idx - 1] or ""

					local is_disabled = false

					-- Cek 2: Inline atau Next-Line Comment Directive (// CFLINT-DISABLE [RULE])
					local check_inline_disable = function(line_str)
						if not line_str then
							return false
						end
						local disabled_rule = line_str:match("CFLINT%-DISABLE%s+([%w_]+)")
							or line_str:match("cflint%-disable%s+([%w_]+)")

						if disabled_rule then
							return disabled_rule == rule_id or disabled_rule == "ALL"
						end

						return line_str:find("CFLINT%-DISABLE") ~= nil or line_str:find("cflint%-disable") ~= nil
					end

					if check_inline_disable(current_line) or check_inline_disable(prev_line) then
						is_disabled = true
					end

					-- Cek 3: Function level Javadoc Annotation (@cflint-ignore MISSING_VAR)
					if not is_disabled and is_ignored_by_function_annotation(line_idx, rule_id) then
						is_disabled = true
					end

					-- Hanya masukkan ke diagnostics jika TIDAK di-ignore
					if not is_disabled then
						table.insert(diagnostics, {
							lnum = line_idx - 1,
							col = (location.column or 1) - 1,
							end_lnum = line_idx - 1,
							end_col = (location.column or 1),
							severity = vim.diagnostic.severity.ERROR,
							message = string.format("[%s] %s", rule_id, issue.message or ""),
							source = "cflint",
						})
					end
				end
			end
		end

		return diagnostics
	end,
}

-- Registry Filetype & Autocmd Trigger
lint.linters_by_ft = lint.linters_by_ft or {}
lint.linters_by_ft.cfml = { "cflint" }
lint.linters_by_ft.cfc = { "cflint" }

vim.api.nvim_create_autocmd({ "BufWritePost", "BufEnter", "InsertLeave" }, {
	callback = function()
		lint.try_lint()
	end,
})

--[[ -- ~/.config/nvim/after/ftplugin/cfml.lua
-- Breadcrumb manual untuk CFML via LSP documentSymbol (bukan nvim-navic)
--
-- Alasan tidak pakai nvim-navic:
-- - documentSymbol dari cfmleditor-lsp mengembalikan range zero-width
--   (start == end), jadi nvim-navic tidak bisa deteksi "cursor di dalam
--   function ini" kecuali cursor persis di baris deklarasi.
-- - grammar tree-sitter-cfml belum granular untuk cfscript (function-function
--   di dalam component cuma satu node flat "cf_component_content"), jadi
--   pendekatan breadcrumb berbasis treesitter murni juga tidak bisa dipakai.
--
-- Solusi: ambil daftar function dari LSP documentSymbol (baris deklarasinya
-- akurat walau range-nya tidak), lalu cari function dengan baris deklarasi
-- terdekat SEBELUM posisi cursor. Nama component diambil dari nama file,
-- karena di CFML nama component = nama file (dan cfmleditor-lsp tidak
-- mengembalikan component sebagai symbol tersendiri).

local cfml_symbols_cache = {}

------------------------------------------------------------
-- Ambil documentSymbol dari LSP client "cfml", simpan ke cache
------------------------------------------------------------
local function cfml_refresh_symbols()
	local bufnr = vim.api.nvim_get_current_buf()
	local clients = vim.lsp.get_clients({ bufnr = bufnr, name = "cfml" })
	if #clients == 0 then
		return
	end

	local params = { textDocument = vim.lsp.util.make_text_document_params(bufnr) }
	clients[1].request("textDocument/documentSymbol", params, function(err, result)
		if err or not result then
			return
		end

		-- flatten (component tidak masuk sebagai symbol, jadi ini cuma function/method)
		local flat = {}
		local function walk(list)
			for _, sym in ipairs(list) do
				table.insert(flat, {
					name = sym.name,
					kind = sym.kind,
					line = sym.range and sym.range.start.line or 0,
				})
				if sym.children then
					walk(sym.children)
				end
			end
		end
		walk(result)

		table.sort(flat, function(a, b)
			return a.line < b.line
		end)

		cfml_symbols_cache[bufnr] = flat
	end, bufnr)
end

------------------------------------------------------------
-- Refresh throttled/debounced: dipanggil tiap TextChanged,
-- tapi request LSP baru dikirim 500ms setelah berhenti mengetik
------------------------------------------------------------
local cfml_refresh_timer = nil

local function cfml_refresh_symbols_throttled()
	if cfml_refresh_timer then
		cfml_refresh_timer:stop()
		cfml_refresh_timer:close()
	end
	cfml_refresh_timer = vim.defer_fn(function()
		cfml_refresh_symbols()
		cfml_refresh_timer = nil
	end, 500)
end

------------------------------------------------------------
-- Susun teks breadcrumb berdasarkan posisi cursor sekarang
------------------------------------------------------------
local function cfml_breadcrumb()
	local bufnr = vim.api.nvim_get_current_buf()
	local parts = {}

	-- Nama component = nama file (konvensi CFML)
	local component_name = vim.fn.expand("%:t:r")
	if component_name ~= "" then
		table.insert(parts, "  " .. component_name)
	end

	local symbols = cfml_symbols_cache[bufnr]
	if symbols and #symbols > 0 then
		local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1 -- 0-indexed
		local function_name

		for _, sym in ipairs(symbols) do
			if sym.line <= cursor_line then
				if sym.kind == 12 or sym.kind == 6 then -- Function / Method
					function_name = sym.name
				end
			else
				break
			end
		end

		if function_name then
			table.insert(parts, "󰊕 " .. function_name)
		end
	end

	return table.concat(parts, " > ")
end

------------------------------------------------------------
-- Autocmd: refresh cache symbol
------------------------------------------------------------
vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "LspAttach" }, {
	buffer = 0,
	callback = function()
		vim.defer_fn(cfml_refresh_symbols, 300)
	end,
})

vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "InsertLeave" }, {
	buffer = 0,
	callback = cfml_refresh_symbols_throttled,
})

------------------------------------------------------------
-- Autocmd: update tampilan winbar saat cursor pindah
------------------------------------------------------------
vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
	buffer = 0,
	callback = function()
		local crumb = cfml_breadcrumb()
		vim.wo.winbar = crumb ~= "" and crumb or ""
	end,
})

------------------------------------------------------------
-- Command manual untuk tes cepat
------------------------------------------------------------
vim.api.nvim_buf_create_user_command(0, "CfmlBreadcrumb", function()
	print(cfml_breadcrumb())
end, { desc = "Tampilkan breadcrumb CFML (via LSP documentSymbol)" })
 ]]

-- config untuk menjalankan commandbox
require("pcode.user.boxrun")
-- cegah snippet load berkali-kali
if vim.g.loaded_cfml_snippets then
	return
end
vim.g.loaded_cfml_snippets = true
-- config for snippets
local ls = require("luasnip")

local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node

local filename = function()
	return vim.fn.expand("%:t:r")
end

ls.add_snippets("cfml", {
	s("componentName", {
		t('component displayname = "'),
		f(filename, {}),
		t('" accessors="true" {'),
		t({ "", "\t" }),
		i(0),
		t({ "", "}" }),
	}),
})

ls.add_snippets("cfml", {
	s("componentInit", {
		t('component displayname = "'),
		f(filename, {}),
		t('" accessors="true" {'),

		t({
			"",
			"",
			"    function init() {",
			"        return this;",
			"    }",
			"",
			"\t",
		}),

		i(0),

		t({
			"",
			"}",
		}),
	}),
})

ls.add_snippets("cfml", {
	s("functionName", {
		t("public any function "),
		i(1, "namaFunction"),
		t("("),
		i(2, "parameter"),
		t({ ") {", "" }),

		t('    _objChange("READ");'),

		t({ "", "    " }),
		i(3),

		t({
			"",
			"}",
		}),
	}),
})

ls.add_snippets("cfml", {
	s("queryExecute", {
		t({
			"queryExecute(",
			'    "',
			"        select",
			"            ",
		}),

		i(1, "emp_id"),

		t({
			"",
			"        from",
			"            ",
		}),

		i(2, "teomempcompany"),

		t({
			"",
			"        where",
			"            company_id=:",
		}),

		i(3, "coid"),

		t({
			"",
			'    ",',
			"    {",
			"        ",
		}),

		i(4, "coid"),

		t({
			":{value:REQUEST.SCookie.",
		}),

		i(5, "coid"),

		t({
			',sqltype:"cf_sql_integer"}',
			"    },",
			"    { datasource:REQUEST.SDSN }",
			");",
		}),
	}),
})

ls.add_snippets("cfml", {
	s("dump", {
		t("Application.AppObj.SFUtil.SFWRITELOG(dump = {data: "),
		i(1, "outData"),
		t("});"),
	}),
})

ls.add_snippets("cfml", {
	s("initUploadProcess", {
		t({
			[[public any function initUpload(struct argEntries) {]],
			[[    _ObjChange("EDIT");]],
			[[    // code mulai dari sini]],
			[[    var bBckGround = argEntries.keyExists("isbackground") ? argEntries.isbackground : 0;]],
			[[    var scheduledate = argEntries.keyExists("isbackground") ? (]],
			[[        argEntries.keyExists("scheduledate") ? argEntries.scheduledate : now()]],
			[[    ) : "";]],
			[[    var blogProc = 1;]],
			[[    var procCode = "ROVT#REQUEST.SCookie.User.uid##dateFormat(now(), "yyyymmdd")##timeFormat(now(), "hhmmss")#";]],
			[[    var procFunc = "qlid=CL_OvertimeReport.processPerData||lastFuncName";]],
			"",
			[[    Application.APPOBJ.SFProcess.InitAttribute({processName: "Overtime Report Process", processModule: "Attendance"});]],
			[[    var retData = Application.APPOBJ.SFProcess.InitProcess(]],
			[[        procCode,]],
			[[        procFunc,]],
			[[        qData,]],
			[[        "",]],
			[[        "",]],
			[[        bBckGround,]],
			[[        scheduledate,]],
			[[        1,]],
			[[        "emp_name"]],
			[[    );]],
			[[    retData.apidirection = "qlid=CL_OvertimeReport.uploadProcess";]],
			[[    return retData;]],
			[[}]],
			"",
			[[public any function lastFuncName(query theQuery) {]],
			[[    try {]],
			[[        // code here]],
			[[        return true;]],
			[[    } catch (e) {]],
			[[        Application.AppObj.SFUtil.SFWRITELOG(dump = {exception: e});]],
			[[        return false;]],
			[[    }]],
			[[}]],
			"",
			[[public any function uploadProcess(struct argEntries) {]],
			[[    _ObjChange("EDIT");]],
			[[    if (isDefined("argEntries.payload")) {]],
			[[        scPassData = deserializeJSON(arguments.argEntries.payload);]],
			[[    } else if (isStruct(argEntries)) {]],
			[[        scPassData = argEntries;]],
			[[    } else {]],
			[[        return {HSTATUS: 400, MESSAGE: "Invalid passing form or payload"};]],
			[[    }]],
			"",
			[[    scPassData.maxprocess = 5;]],
			[[    var retData = Application.APPOBJ.SFProcess.runProcess(argumentcollection = scPassData);]],
			[[    retData.apidirection = "qlid=CL_OvertimeReport.uploadProcess";]],
			[[    return retData;]],
			[[}]],
			"",
			[[public any function processPerData(string processCode, numeric currow, query qData) {]],
			[[    try {]],
			[[        // code here]],
			[[    } catch (any e) {]],
			[[        LOCAL.pathlog = Application.AppObj.SFUtil.SFWRITELOG(dump = {catch: e});]],
			[[        LOCAL.empName = qData.emp_name[currow];]],
			[[        Application.APPOBJ.SFProcess.AddFailure(]],
			[[            Arguments.processcode,]],
			[[            Arguments.rowData.seq_id,]],
			[[            "Error Overtime Report For : " & LOCAL.empName,]],
			[[            "#LOCAL.pathlog#"]],
			[[        );]],
			[[        return false;]],
			[[    }]],
			[[    return true;]],
			[[}]],
		}),

		i(0),
	}),

	s("testFunction", {
		t({
			[[function test() {]],
			[[    this._ObjChange("READ");]],
			[[    return {status: true, message: "Message Ok !"}]],
			[[}]],
		}),

		i(0),
	}),

	s("remark", {
		t({ "/**", " * add by akn " }),
		f(function()
			return os.date("%Y%m%d %H:%M")
		end, {}),
		t({ "", " * " }),
		i(0),
		t({ "", " */" }),
	}),
})
