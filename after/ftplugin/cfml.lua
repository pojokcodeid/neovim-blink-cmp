-- ~/.config/nvim/after/ftplugin/cfml.lua
-- Konfigurasi filetype CFML: indent, auto-close tag, CFLint, comment, snippets.
--
-- Struktur:
--   1. Bagian buffer-local  -> dijalankan setiap buffer CFML dibuka
--   2. Bagian global        -> dijalankan SEKALI saja (guard di tengah file)

local api = vim.api
local fn = vim.fn
local bo = vim.bo

-- ============================================================================
-- 1. Buffer-local
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Indent & tab
-- ---------------------------------------------------------------------------
bo.cindent = true
bo.smartindent = false
bo.autoindent = true
bo.indentexpr = "" -- pakai cindent, bukan indentexpr
bo.expandtab = true
bo.shiftwidth = 4
bo.tabstop = 4

-- Hapus trigger '0#' dari cinkeys (yang memaksa '#' ke kolom 0)
bo.cinkeys = (bo.cinkeys:gsub(",?0#", ""))

-- Align kurung kurawal { } & pemicu kata kunci
bo.cinoptions = "{0,}0,j1,J1"
bo.cinwords = "component,function,if,else,for,while,switch,try,catch"

-- .cfm memakai gaya tag, .cfc/.sfc memakai cfscript
bo.commentstring = fn.expand("%:e") == "cfm" and "<!--- %s --->" or "// %s"

-- ---------------------------------------------------------------------------
-- Auto-close tag
-- Whitelist tag yang butuh penutup. Tag self-closing (cfset, cfparam,
-- cfinclude, dll) SENGAJA tidak dimasukkan.
-- ---------------------------------------------------------------------------
local CLOSING_TAGS = {}
for _, name in ipairs({
	-- kontrol alur
	"cfif",
	"cfelseif",
	"cfelse",
	"cfloop",
	"cfswitch",
	"cfcase",
	"cfdefaultcase",
	-- error handling
	"cftry",
	"cfcatch",
	"cffinally",
	-- struktur
	"cfcomponent",
	"cffunction",
	"cfscript",
	"cfoutput",
	-- lain-lain
	"cflock",
	"cftransaction",
	"cfsavecontent",
	"cfquery",
	"cfstoredproc",
	"cfmail",
	"cfhttp",
	"cfthread",
	"cfzip",
	"cfpdf",
	"cfdocument",
}) do
	CLOSING_TAGS[name] = true
end

--- Sisipkan teks di (row 1-indexed, col 0-indexed) pada buffer aktif.
local function insert_text(row, col, text)
	api.nvim_buf_set_text(0, row - 1, col, row - 1, col, { text })
end

--- Ketik ">" setelah "<cfif ..." -> menjadi "<cfif ...></cfif>"
local function auto_close_on_gt()
	local row, col = unpack(api.nvim_win_get_cursor(0))
	local before = api.nvim_get_current_line():sub(1, col)

	-- tag self-closing (<cfif ... />) tidak di-auto-close
	local tagname = not before:match("/%s*$") and before:match("<(%a[%w_]*)[^<>]*$")

	insert_text(row, col, ">")
	if tagname and CLOSING_TAGS[tagname:lower()] then
		insert_text(row, col + 1, "</" .. tagname .. ">")
	end
	api.nvim_win_set_cursor(0, { row, col + 1 })
end

--- Enter di antara tag pembuka & penutup -> 3 baris. Selain itu serahkan ke
--- nvim-autopairs agar expand {}, (), [] bawaan plugin tetap jalan.
local function expand_on_cr()
	local row, col = unpack(api.nvim_win_get_cursor(0))
	local line = api.nvim_get_current_line()
	local before, after = line:sub(1, col), line:sub(col + 1)

	if before:match(">%s*$") and after:match("^</%a[%w_]*>") then
		local indent = line:match("^%s*")
		local middle = indent .. (bo.expandtab and (" "):rep(fn.shiftwidth()) or "\t")

		api.nvim_buf_set_lines(0, row - 1, row, false, { before, middle, indent .. after })
		api.nvim_win_set_cursor(0, { row + 1, #middle })
		return
	end

	local ok, npairs = pcall(require, "nvim-autopairs")
	local keys
	if ok and npairs.autopairs_cr then
		keys = npairs.autopairs_cr()
	else
		keys = api.nvim_replace_termcodes("<CR>", true, false, true)
	end
	api.nvim_feedkeys(keys, "n", false)
end

vim.keymap.set("i", ">", auto_close_on_gt, { buffer = true, desc = "Auto close CFML tag" })
vim.keymap.set("i", "<CR>", expand_on_cr, { buffer = true, desc = "Expand CFML tag block on Enter" })

-- Runner CommandBox (require ter-cache, aman dipanggil berulang)
require("pcode.user.boxrun")

-- ============================================================================
-- 2. Global (sekali saja)
-- ============================================================================
if vim.g.loaded_cfml_ftplugin then
	return
end
-- flag di-set di akhir setup global (setelah snippets), supaya error di tengah
-- tidak membuat setup berikutnya terlewati

-- ---------------------------------------------------------------------------
-- Comment.nvim
-- ---------------------------------------------------------------------------
do
	local U = require("Comment.utils")

	-- Comment.ft.set(filetype, { linewise, blockwise })
	require("Comment.ft").set("cfml", { "// %s", "/* %s */" }) -- default .cfc/.sfc

	require("Comment").setup({
		pre_hook = function(ctx)
			-- hanya untuk CFML; filetype lain pakai commentstring bawaan
			if vim.bo.filetype ~= "cfml" then
				return
			end
			-- .cfm selalu gaya tag (linewise & blockwise sama)
			if fn.expand("%:e") == "cfm" then
				return "<!--- %s --->"
			end
			-- .cfc / .sfc -> cfscript
			return ctx.ctype == U.ctype.linewise and "// %s" or "/* %s */"
		end,
	})
end

-- ---------------------------------------------------------------------------
-- CFLint via nvim-lint (CommandBox: `box cflint`)
--
-- Cara mengabaikan rule:
--   1. // CFLINT-DISABLE              -> abaikan per baris (di atas / di samping)
--   2. // CFLINT-DISABLE MISSING_VAR  -> abaikan rule tertentu saja
--   3. Per fungsi / component:
--        /**
--        * @cflint-ignore MISSING_VAR
--        */
--        public any function approve(required string RequestKey) { ... }
--   4. Global via file .cflintrc:
--        { "excludes": [ { "name": "MISSING_VAR" } ] }
-- ---------------------------------------------------------------------------
do
	local lint = require("lint")

	local ANSI_PATTERN = "\27%[[%d;]*m"
	local LINT_LINE = "^%s*(%u+):%s*([%u_]+),%s*(.-)%s*%[(%d+),(%d+)%]%s*$"

	local IGNORE_RULE_PATTERNS = {
		"@cflint%-ignore%s+([%w_]+)",
		"@cflint%-disable%s+([%w_]+)",
		"cflint%-ignore%s+([%w_]+)",
	}
	local IGNORE_ANY_PATTERNS = { "@cflint%-ignore", "@cflint%-disable", "cflint%-ignore" }
	local FUNCTION_PATTERNS = {
		"function%s+[%w_]+%s*%(",
		"function%s+[%w_]+%s*[%w_]+%s*%(",
		"function%s*%(",
	}

	local function match_first(str, patterns)
		for _, p in ipairs(patterns) do
			local m = str:match(p)
			if m then
				return m
			end
		end
	end

	local function matches_any(str, patterns)
		for _, p in ipairs(patterns) do
			if str:find(p) then
				return true
			end
		end
		return false
	end

	local function count(str, pattern)
		return select(2, str:gsub(pattern, ""))
	end

	--- Baca rule yang di-exclude dari .cflintrc terdekat (jika ada).
	local function get_excluded_rules(bufnr)
		local found = vim.fs.find(".cflintrc", { path = api.nvim_buf_get_name(bufnr), upward = true })[1]
		if not found then
			return {}
		end

		local f = io.open(found, "r")
		if not f then
			return {}
		end
		local content = f:read("*a")
		f:close()

		local ok, decoded = pcall(vim.json.decode, content)
		if not ok or type(decoded) ~= "table" or not decoded.excludes then
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

	--- Scan buffer: kumpulkan rentang tiap fungsi beserta anotasi ignore-nya.
	local function scan_function_ignores(lines)
		local ranges = {}
		local rules, start, depth, in_function = {}, nil, 0, false

		for idx, line in ipairs(lines) do
			local rule = match_first(line, IGNORE_RULE_PATTERNS)
			if rule then
				rules[#rules + 1] = rule
			elseif matches_any(line, IGNORE_ANY_PATTERNS) then
				rules[#rules + 1] = "ALL"
			end

			if matches_any(line, FUNCTION_PATTERNS) then
				start, in_function, depth = idx, true, 0
			end

			if in_function then
				depth = depth + count(line, "{") - count(line, "}")
				if depth <= 0 and line:find("}") then
					ranges[#ranges + 1] = { start_line = start, end_line = idx, rules = rules }
					in_function, start, rules = false, nil, {}
				end
			end
		end

		return ranges
	end

	local function ignored_in_function(ranges, line_idx, rule_id)
		for _, range in ipairs(ranges) do
			if line_idx >= range.start_line and line_idx <= range.end_line then
				for _, r in ipairs(range.rules) do
					if r == rule_id or r == "ALL" then
						return true
					end
				end
			end
		end
		return false
	end

	--- Cek komentar CFLINT-DISABLE di satu baris untuk rule tertentu.
	local function has_disable_comment(line_str, rule_id)
		if not line_str then
			return false
		end
		local rule = line_str:match("CFLINT%-DISABLE%s+([%w_]+)") or line_str:match("cflint%-disable%s+([%w_]+)")
		if rule then
			return rule == rule_id or rule == "ALL"
		end
		return line_str:find("CFLINT%-DISABLE") ~= nil or line_str:find("cflint%-disable") ~= nil
	end

	lint.linters.cflint = {
		cmd = "box",
		args = {
			"cflint",
			function()
				return "pattern=" .. fn.fnamemodify(api.nvim_buf_get_name(0), ":t")
			end,
			"reportLevel=ERROR",
		},
		-- Jalankan dari folder tempat file berada
		cwd = function()
			return fn.fnamemodify(api.nvim_buf_get_name(0), ":h")
		end,
		stdin = false,
		stream = "both", -- CommandBox kadang mengirim log ke stderr
		ignore_exitcode = true,
		parser = function(output, bufnr)
			if not output or output == "" then
				return {}
			end

			-- Hilangkan ANSI escape codes (warna terminal CommandBox)
			local clean_output = output:gsub(ANSI_PATTERN, "")

			local excludes = get_excluded_rules(bufnr)
			local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
			local function_ranges = scan_function_ignores(lines)
			local diagnostics = {}

			-- Format: ERROR: MISSING_VAR, Variable ... [1408,10]
			for line in clean_output:gmatch("[^\r\n]+") do
				local sev, rule_id, detail_msg, lnum, col = line:match(LINT_LINE)

				if sev == "ERROR" and not excludes[rule_id] then
					local row = tonumber(lnum) or 1
					local column = tonumber(col) or 1

					local disabled = has_disable_comment(lines[row], rule_id)
						or has_disable_comment(lines[row - 1], rule_id)
						or ignored_in_function(function_ranges, row, rule_id)

					if not disabled then
						diagnostics[#diagnostics + 1] = {
							lnum = row - 1,
							col = column - 1,
							end_lnum = row - 1,
							end_col = column,
							severity = vim.diagnostic.severity.ERROR,
							message = string.format("%s (%s)", detail_msg, rule_id),
							source = "cflint",
						}
					end
				end
			end

			return diagnostics
		end,
	}

	lint.linters_by_ft = lint.linters_by_ft or {}
	lint.linters_by_ft.cfml = { "cflint" }
	lint.linters_by_ft.cfc = { "cflint" }

	api.nvim_create_autocmd({ "BufWritePost", "BufEnter", "InsertLeave" }, {
		group = api.nvim_create_augroup("CfmlLint", { clear = true }),
		callback = function()
			lint.try_lint()
		end,
	})
end

-- ---------------------------------------------------------------------------
-- Snippets (LuaSnip)
-- ---------------------------------------------------------------------------
-- cegah snippet load berkali-kali
if not vim.g.loaded_cfml_snippets then
	vim.g.loaded_cfml_snippets = true

	local ls = require("luasnip")
	local s, t, i, f = ls.snippet, ls.text_node, ls.insert_node, ls.function_node

	local function filename()
		return fn.expand("%:t:r")
	end

	--- Node baru harus dibuat per snippet (node tidak boleh dipakai ulang).
	local function component_header()
		return { t('component displayname = "'), f(filename, {}), t('" accessors="true" {') }
	end

	local function split_lines(text)
		return vim.split(text, "\n", { plain = true })
	end

	local init_upload_body = [==[
public any function initUpload(struct argEntries) {
    _ObjChange("EDIT");
    // code mulai dari sini
    var bBckGround = argEntries.keyExists("isbackground") ? argEntries.isbackground : 0;
    var scheduledate = argEntries.keyExists("isbackground") ? (
        argEntries.keyExists("scheduledate") ? argEntries.scheduledate : now()
    ) : "";
    var blogProc = 1;
    var procCode = "ROVT#REQUEST.SCookie.User.uid##dateFormat(now(), "yyyymmdd")##timeFormat(now(), "hhmmss")#";
    var procFunc = "qlid=CL_OvertimeReport.processPerData||lastFuncName";

    Application.APPOBJ.SFProcess.InitAttribute({processName: "Overtime Report Process", processModule: "Attendance"});
    var retData = Application.APPOBJ.SFProcess.InitProcess(
        procCode,
        procFunc,
        qData,
        "",
        "",
        bBckGround,
        scheduledate,
        1,
        "emp_name"
    );
    retData.apidirection = "qlid=CL_OvertimeReport.uploadProcess";
    return retData;
}

public any function lastFuncName(query theQuery) {
    try {
        // code here
        return true;
    } catch (e) {
        Application.AppObj.SFUtil.SFWRITELOG(dump = {exception: e});
        return false;
    }
}

public any function uploadProcess(struct argEntries) {
    _ObjChange("EDIT");
    if (isDefined("argEntries.payload")) {
        scPassData = deserializeJSON(arguments.argEntries.payload);
    } else if (isStruct(argEntries)) {
        scPassData = argEntries;
    } else {
        return {HSTATUS: 400, MESSAGE: "Invalid passing form or payload"};
    }

    scPassData.maxprocess = 5;
    var retData = Application.APPOBJ.SFProcess.runProcess(argumentcollection = scPassData);
    retData.apidirection = "qlid=CL_OvertimeReport.uploadProcess";
    return retData;
}

public any function processPerData(string processCode, numeric currow, query qData) {
    try {
        // code here
    } catch (any e) {
        LOCAL.pathlog = Application.AppObj.SFUtil.SFWRITELOG(dump = {catch: e});
        LOCAL.empName = qData.emp_name[currow];
        Application.APPOBJ.SFProcess.AddFailure(
            Arguments.processcode,
            Arguments.rowData.seq_id,
            "Error Overtime Report For : " & LOCAL.empName,
            "#LOCAL.pathlog#"
        );
        return false;
    }
    return true;
}]==]

	ls.add_snippets("cfml", {
		s(
			"componentName",
			vim.list_extend(component_header(), {
				t({ "", "\t" }),
				i(0),
				t({ "", "}" }),
			})
		),

		s(
			"componentInit",
			vim.list_extend(component_header(), {
				t({ "", "", "    function init() {", "        return this;", "    }", "", "\t" }),
				i(0),
				t({ "", "}" }),
			})
		),

		s("functionName", {
			t("public any function "),
			i(1, "namaFunction"),
			t("("),
			i(2, "parameter"),
			t({ ") {", '    _objChange("READ");', "    " }),
			i(3),
			t({ "", "}" }),
		}),

		s("queryExecute", {
			t({ "queryExecute(", '    "', "        select", "            " }),
			i(1, "emp_id"),
			t({ "", "        from", "            " }),
			i(2, "teomempcompany"),
			t({ "", "        where", "            company_id=:" }),
			i(3, "coid"),
			t({ "", '    ",', "    {", "        " }),
			i(4, "coid"),
			t(":{value:REQUEST.SCookie."),
			i(5, "coid"),
			t({ ',sqltype:"cf_sql_integer"}', "    },", "    { datasource:REQUEST.SDSN }", ");" }),
		}),

		s("dump", {
			t("Application.AppObj.SFUtil.SFWRITELOG(dump = {data: "),
			i(1, "outData"),
			t("});"),
		}),

		s("initUploadProcess", {
			t(split_lines(init_upload_body)),
			i(0),
		}),

		s("testFunction", {
			t({
				"function test() {",
				'    this._ObjChange("READ");',
				'    return {status: true, message: "Message Ok !"}',
				"}",
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
	}, { key = "cfml_custom" }) -- key: reload mengganti snippet lama, bukan menambah duplikat
end

vim.g.loaded_cfml_ftplugin = true

--[[ Breadcrumb manual CFML via LSP documentSymbol (NONAKTIF)

Alasan tidak pakai nvim-navic:
- documentSymbol dari cfmleditor-lsp mengembalikan range zero-width
  (start == end), sehingga nvim-navic tidak bisa mendeteksi "cursor di dalam
  function ini" kecuali cursor persis di baris deklarasi.
- Grammar tree-sitter-cfml belum granular untuk cfscript, jadi breadcrumb
  berbasis treesitter murni juga tidak bisa dipakai.

Solusi: ambil daftar function dari LSP documentSymbol (baris deklarasinya
akurat), lalu cari function dengan baris deklarasi terdekat SEBELUM cursor.
Nama component diambil dari nama file (konvensi CFML).

local symbols_cache = {}

local function refresh_symbols()
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

		local flat = {}
		local function walk(list)
			for _, sym in ipairs(list) do
				flat[#flat + 1] = {
					name = sym.name,
					kind = sym.kind,
					line = sym.range and sym.range.start.line or 0,
				}
				if sym.children then
					walk(sym.children)
				end
			end
		end
		walk(result)

		table.sort(flat, function(a, b)
			return a.line < b.line
		end)
		symbols_cache[bufnr] = flat
	end, bufnr)
end

-- Debounce: request LSP dikirim 500ms setelah berhenti mengetik
local refresh_timer = nil
local function refresh_symbols_debounced()
	if refresh_timer then
		refresh_timer:stop()
		refresh_timer:close()
	end
	refresh_timer = vim.defer_fn(function()
		refresh_symbols()
		refresh_timer = nil
	end, 500)
end

local function breadcrumb()
	local parts = {}

	local component_name = vim.fn.expand("%:t:r")
	if component_name ~= "" then
		parts[#parts + 1] = "  " .. component_name
	end

	local symbols = symbols_cache[vim.api.nvim_get_current_buf()]
	if symbols and #symbols > 0 then
		local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1
		local function_name

		for _, sym in ipairs(symbols) do
			if sym.line > cursor_line then
				break
			end
			if sym.kind == 12 or sym.kind == 6 then -- Function / Method
				function_name = sym.name
			end
		end

		if function_name then
			parts[#parts + 1] = "󰊕 " .. function_name
		end
	end

	return table.concat(parts, " > ")
end

vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "LspAttach" }, {
	buffer = 0,
	callback = function()
		vim.defer_fn(refresh_symbols, 300)
	end,
})

vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "InsertLeave" }, {
	buffer = 0,
	callback = refresh_symbols_debounced,
})

vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
	buffer = 0,
	callback = function()
		vim.wo.winbar = breadcrumb()
	end,
})

vim.api.nvim_buf_create_user_command(0, "CfmlBreadcrumb", function()
	print(breadcrumb())
end, { desc = "Tampilkan breadcrumb CFML (via LSP documentSymbol)" })
]]
