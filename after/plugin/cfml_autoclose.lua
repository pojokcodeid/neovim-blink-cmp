-- ~/.config/nvim/after/plugin/cfml_autoclose.lua
-- Auto close tag CFML + HTML saat mengetik ">" (tanpa Treesitter).

-- Tag yang tidak punya tag penutup
local VOID = {}
for w in
	([[br hr img input meta link area base col embed source track wbr
  cfset cfargument cfparam cfinclude cfreturn cfqueryparam cfelse cfelseif
  cfbreak cfcontinue cfabort cfdump cfheader cflocation cfthrow cfrethrow
  cfimport cfsetting cfflush cfexit cfmailparam cfhttpparam cfprocparam]]):gmatch("%S+")
do
	VOID[w] = true
end

local function close_tag()
	local line = vim.api.nvim_get_current_line()
	local col = vim.api.nvim_win_get_cursor(0)[2]
	local before = line:sub(1, col)
	local after = line:sub(col + 1)

	-- tag yang sedang dibuka: <nama atribut...   (belum ditutup dengan >)
	local tag = before:match("<([%a][%w:_%-%.]*)[^<>]*$")
	if not tag then
		return ">"
	end

	-- self-closing (<tag ... />) atau tag tanpa penutup
	if before:match("/%s*$") or VOID[tag:lower()] then
		return ">"
	end

	-- sudah ada penutupnya tepat setelah kursor
	if after:lower():match("^</" .. tag:lower() .. ">") then
		return ">"
	end

	-- sisipkan </tag> lalu geser kursor ke antara kedua tag
	return ">" .. "</" .. tag .. ">" .. string.rep("<Left>", #tag + 3)
end

local function attach(buf)
	vim.keymap.set("i", ">", close_tag, { buffer = buf, expr = true, desc = "CFML auto close tag" })
end

vim.api.nvim_create_autocmd("FileType", {
	pattern = { "cfml", "cfm", "cfc", "coldfusion" },
	callback = function(a)
		attach(a.buf)
	end,
})

-- buffer CFML yang sudah terbuka saat file ini dimuat
for _, b in ipairs(vim.api.nvim_list_bufs()) do
	local ft = vim.bo[b].filetype
	if ft == "cfml" or ft == "cfm" or ft == "cfc" or ft == "coldfusion" then
		attach(b)
	end
end
