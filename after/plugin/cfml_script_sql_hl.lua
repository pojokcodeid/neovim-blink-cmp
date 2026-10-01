-- ~/.config/nvim/after/plugin/cfml_script_sql_hl.lua
-- Pewarnaan SQL di dalam string CFScript, mis.
--   qTextQuery = "UPDATE tabel SET kolom = :param ...";
-- Memakai extmark, jadi tidak terpengaruh node ERROR dari parser SQL.
-- Group warna CfmlSql* sama dengan cfml_query_hl.lua.

local ns = vim.api.nvim_create_namespace("cfml_script_sql")

-- ─── Warna (default = true: tidak menimpa definisi di file lain) ────────
local SQL_LINKS = {
	CfmlSqlKeyword = "@keyword",
	CfmlSqlFunction = "@function.call",
	CfmlSqlNumber = "@number",
	CfmlSqlString = "@string",
	CfmlSqlComment = "@comment",
	CfmlSqlTable = "@type",
	CfmlSqlColumn = "@variable.member",
	CfmlSqlOperator = "@operator",
}
local function sql_colors()
	for group, target in pairs(SQL_LINKS) do
		vim.api.nvim_set_hl(0, group, { link = target, default = true })
	end
end
sql_colors()
vim.api.nvim_create_autocmd("ColorScheme", { callback = sql_colors })

-- ─── Keyword SQL ────────────────────────────────────────────────────────
local KW = {}
for w in
	([[select from where and or not in is null as join left right inner
  outer full cross on group by order having case when then else end insert
  into values update set delete union all distinct top like between exists
  asc desc limit with over partition offset fetch next rows only create
  table alter drop index primary key default cast convert]]):gmatch("%a+")
do
	KW[w] = true
end
local TABLE_KW = { from = true, join = true, into = true, update = true, table = true }

-- string dianggap SQL kalau diawali salah satu kata ini + spasi
local SQL_START = { "select", "insert", "update", "delete", "with" }
local function looks_like_sql(s)
	local l = s:lower()
	for _, k in ipairs(SQL_START) do
		if l:match("^%s*" .. k .. "%s") then
			return true
		end
	end
	return false
end

local P = { sql = 250, ident = 253, str = 260, comment = 265, hash = 330 }

local query_cache
local function get_query()
	if query_cache == nil then
		local ok, q = pcall(vim.treesitter.query.parse, "cfscript", "(string) @s")
		query_cache = ok and q or false
	end
	return query_cache
end

local function apply(buf)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

	local q = get_query()
	if not q then
		return
	end
	local ok, parser = pcall(vim.treesitter.get_parser, buf)
	if not ok or not parser then
		return
	end
	pcall(function()
		parser:parse(true)
	end)

	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local text = table.concat(lines, "\n")

	local starts, o = {}, 0
	for i, l in ipairs(lines) do
		starts[i] = o
		o = o + #l + 1
	end

	local function pos(byte)
		local lo, hi = 1, #starts
		while lo < hi do
			local mid = math.ceil((lo + hi) / 2)
			if starts[mid] <= byte then
				lo = mid
			else
				hi = mid - 1
			end
		end
		return lo - 1, byte - starts[lo]
	end

	local function mark(s, e, hl, prio)
		local r1, c1 = pos(s - 1)
		local r2, c2 = pos(e)
		vim.api.nvim_buf_set_extmark(buf, ns, r1, c1, {
			end_row = r2,
			end_col = c2,
			hl_group = hl,
			priority = prio,
		})
	end

	-- 1-based offset byte dari (row, col) 0-based
	local function off(row, col)
		return starts[row + 1] + col + 1
	end

	local raw_mark = mark

	local function color_sql(r1, r2)
		-- rentang #...# (ekspresi CFML): dikembalikan ke highlight CFML standar
		local hashes = {}
		local hp = r1
		while true do
			local hs, he = text:find("#[^#\n]+#", hp)
			if not hs or hs > r2 then
				break
			end
			hashes[#hashes + 1] = { hs, he }
			hp = he + 1
		end

		-- mark khusus SQL: lewati bagian yang berada di dalam #...#
		local function mark(s, e, hl, prio)
			local cur = s
			for _, h in ipairs(hashes) do
				if h[2] >= cur and h[1] <= e then
					if h[1] > cur then
						raw_mark(cur, h[1] - 1, hl, prio)
					end
					cur = math.max(cur, h[2] + 1)
					if cur > e then
						return
					end
				end
			end
			if cur <= e then
				raw_mark(cur, e, hl, prio)
			end
		end

		-- :parameter
		local p = r1
		while true do
			local s, e = text:find(":[%a_][%w_]*", p)
			if not s or s > r2 then
				break
			end
			mark(s, s, "CfmlSqlOperator", P.ident + 1)
			mark(s + 1, e, "CfmlSqlColumn", P.ident + 1)
			p = e + 1
		end

		-- qualifier.kolom
		p = r1
		while true do
			local s, e, qn, cn = text:find("([%a_][%w_]*)%.([%a_][%w_]*)", p)
			if not s or s > r2 then
				break
			end
			mark(s, s + #qn - 1, "CfmlSqlTable", P.ident)
			mark(e - #cn + 1, e, "CfmlSqlColumn", P.ident)
			p = e + 1
		end

		-- kata: keyword, fungsi, tabel, alias, kolom polos
		local state, pe, prevw = 0, r1 - 1, ""
		p = r1
		while true do
			local s, e = text:find("[%a_][%w_]*", p)
			if not s or s > r2 then
				break
			end
			local w = text:sub(s, e):lower()
			local isfn = text:sub(e + 1, e + 1) == "("
			local is_table = false

			if state == 1 then
				if KW[w] then
					state = 0
				else
					mark(s, e, "CfmlSqlTable", P.ident)
					is_table = true
					state = 2
				end
			elseif state == 2 then
				local gap = text:sub(pe + 1, s - 1)
				if gap == "." then
					mark(s, e, "CfmlSqlTable", P.ident)
					is_table = true
				else
					state = 0
					if not KW[w] and not isfn and gap:match("^%s+$") then
						mark(s, e, "CfmlSqlTable", P.ident)
						is_table = true
					end
				end
			end

			-- kata setelah ":" adalah parameter, sudah diwarnai di atas
			local after_colon = text:sub(s - 1, s - 1) == ":"

			if KW[w] and not after_colon then
				mark(s, e, "CfmlSqlKeyword", P.sql)
				if TABLE_KW[w] then
					state = 1
				end
			elseif isfn then
				mark(s, e, "CfmlSqlFunction", P.sql)
			elseif not is_table and not after_colon and prevw ~= "as" then
				mark(s, e, "CfmlSqlColumn", P.sql + 1)
			end

			prevw = w
			pe = e
			p = e + 1
		end

		-- angka
		p = r1
		while true do
			local s, e = text:find("%f[%w_]%d+%.?%d*%f[^%w_]", p)
			if not s or s > r2 then
				break
			end
			mark(s, e, "CfmlSqlNumber", P.sql)
			p = e + 1
		end

		-- operator
		p = r1
		while true do
			local s, e = text:find("[=<>!+*/%%]+", p)
			if not s or s > r2 then
				break
			end
			mark(s, e, "CfmlSqlOperator", P.ident)
			p = e + 1
		end

		-- string '...'
		p = r1
		while true do
			local s, e = text:find("'[^'\n]*'", p)
			if not s or s > r2 then
				break
			end
			mark(s, e, "CfmlSqlString", P.str)
			p = e + 1
		end

		-- komentar SQL --
		p = r1
		while true do
			local s, e = text:find("%-%-[^\n]*", p)
			if not s or s > r2 then
				break
			end
			mark(s, e, "CfmlSqlComment", P.comment)
			p = e + 1
		end
	end

	parser:for_each_tree(function(tree, ltree)
		if ltree:lang() ~= "cfscript" then
			return
		end
		for _, node in q:iter_captures(tree:root(), buf) do
			local sr, sc, er, ec = node:range()
			-- isi string tanpa tanda kutip
			local r1 = off(sr, sc) + 1
			local r2 = off(er, ec - 1) - 1
			if r2 > r1 and looks_like_sql(text:sub(r1, r2)) then
				color_sql(r1, r2)
			end
		end
	end)
end

local group = vim.api.nvim_create_augroup("CfmlScriptSql", { clear = true })
vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "TextChanged", "InsertLeave" }, {
	group = group,
	pattern = { "*.cfc", "*.cfm" },
	callback = function(a)
		apply(a.buf)
	end,
})

for _, b in ipairs(vim.api.nvim_list_bufs()) do
	local name = vim.api.nvim_buf_get_name(b)
	if name:match("%.cfc$") or name:match("%.cfm$") then
		apply(b)
	end
end
