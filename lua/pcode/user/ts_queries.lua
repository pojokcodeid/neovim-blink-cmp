-- lua/user/ts_queries.lua
local M = {}

M.sources = {
	cfml = {
		repo = "cfmleditor/tree-sitter-cfml",
		branch = "master",
		path = "cfml/queries",
		files = { "highlights.scm", "injections.scm", "indents.scm", "tags.scm" },
	},
	cfscript = {
		repo = "cfmleditor/tree-sitter-cfml",
		branch = "master",
		path = "cfscript/queries",
		files = { "highlights.scm", "tags.scm" },
	},
}

--- Patch regex predicate (#match?/#not-match?/#any-of?/#vim-match?) supaya
--- kompatibel dengan vim.regex Neovim, dengan prefix \v (very magic mode).
--- Query file grammar non-official biasanya ditulis untuk PCRE/Rust-regex,
--- bukan Vim regex, sehingga karakter seperti ? + ( ) perlu \v supaya
--- diperlakukan sebagai metacharacter (bukan literal).
---@param filepath string
---@return integer jumlah pattern yang dipatch
local function patch_vim_regex(filepath)
	local f = io.open(filepath, "r")
	if not f then
		return 0
	end
	local content = f:read("*a")
	f:close()

	local count = 0
	local patched = content:gsub('(#[%w%-]*match%??%s+@[%w%.]+%s*)"([^"]*)"', function(prefix, pattern)
		local original = pattern

		-- (?i) ala PCRE tidak dikenal Vim regex; gantikan dengan \c (case-insensitive flag Vim)
		pattern = pattern:gsub("%(%?i%)", "\\c")

		-- tambahkan \v (very magic) di depan kalau belum ada, supaya ?, +, (, ), | dst.
		-- diperlakukan sebagai metachar (setara PCRE), bukan literal
		if pattern:sub(1, 2) ~= "\\v" then
			pattern = "\\v" .. pattern
		end

		if pattern ~= original then
			count = count + 1
		end
		return prefix .. '"' .. pattern .. '"'
	end)

	if count > 0 then
		local out = io.open(filepath, "w")
		if out then
			out:write(patched)
			out:close()
		end
	end
	return count
end

local function download_one(name)
	local src = M.sources[name]
	if not src then
		vim.notify(("[ts_queries] Tidak ada source terdaftar untuk '%s'"):format(name), vim.log.levels.ERROR)
		return
	end

	local dest_dir = vim.fs.joinpath(vim.fn.stdpath("config"), "queries", name)
	vim.fn.mkdir(dest_dir, "p")

	for _, file in ipairs(src.files) do
		local url = ("https://raw.githubusercontent.com/%s/%s/%s/%s"):format(src.repo, src.branch, src.path, file)
		local dest = vim.fs.joinpath(dest_dir, file)

		vim.system({ "curl", "-fsSL", "-o", dest, url }, { text = true }, function(result)
			vim.schedule(function()
				if result.code ~= 0 then
					vim.notify(
						("[ts_queries] GAGAL %s/%s (exit %d)\n%s"):format(name, file, result.code, result.stderr or ""),
						vim.log.levels.ERROR
					)
					return
				end

				local n = patch_vim_regex(dest)
				if n > 0 then
					vim.notify(("[ts_queries] OK  %s/%s (%d regex dipatch ke \\v)"):format(name, file, n))
				else
					vim.notify(("[ts_queries] OK  %s/%s"):format(name, file))
				end
			end)
		end)
	end
end

function M.download(names)
	if not names or #names == 0 then
		names = vim.tbl_keys(M.sources)
	end
	for _, name in ipairs(names) do
		download_one(name)
	end
end

function M.setup()
	vim.api.nvim_create_user_command("TSDownloadQueries", function(opts)
		M.download(opts.fargs)
	end, {
		nargs = "*",
		complete = function()
			return vim.tbl_keys(M.sources)
		end,
		desc = "Download & patch tree-sitter query files untuk parser custom (mis. cfml, cfscript)",
	})
end

return M
