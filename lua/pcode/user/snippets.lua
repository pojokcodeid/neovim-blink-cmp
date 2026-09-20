local status_ok = pcall(require, "luasnip")
if not status_ok then
	return
end
local luasnip = require("luasnip")

-- Menyuruh LuaSnip menggunakan snippet 'cfml' untuk filetype 'cfc', 'cfm', dan 'html'
luasnip.filetype_extend("cfc", { "cfml", "html" })
luasnip.filetype_extend("cfm", { "cfml", "html" })
luasnip.filetype_extend("cfml", { "html" }) -- Jika butuh tag HTML di dalam CFML

local lpath = vim.fn.stdpath("config") .. "/snippets"
require("luasnip.loaders.from_vscode").lazy_load({ paths = lpath })
require("luasnip.loaders.from_vscode").load({ paths = lpath })
