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
