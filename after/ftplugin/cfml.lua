-- Hapus alert / print sebelumnya

-- Force cindent & indentexpr khusus buffer CFML
vim.bo.cindent = true
vim.bo.smartindent = false
vim.bo.indentexpr = "cindent(v:lnum)"

-- Formatting tab/spasi
vim.bo.expandtab = true
vim.bo.shiftwidth = 4
vim.bo.tabstop = 4

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
		local keys = vim.api.nvim_replace_termcodes("<CR>", true, false, true)
		vim.api.nvim_feedkeys(keys, "n", false)
	end
end

vim.keymap.set("i", "<CR>", cfml_expand_on_cr, {
	buffer = true,
	desc = "Expand CFML tag block on Enter",
})

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

		t('    _objectChange("READ");'),

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
			":{value:request.cookie.",
		}),

		i(5, "coid"),

		t({
			',sqltype:"cf_sql_integer"}',
			"    },",
			"    {",
			"        datasource:request.sdsn",
			"    }",
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
