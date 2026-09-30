-- ~/.config/nvim/after/plugin/cfml_query_hl.lua
-- Pewarnaan isi <cfquery> pada file CFML (.cfc / .cfm) memakai extmark,
-- karena parser Treesitter gagal membaca SQL yang bercampur tag CFML.

local ns = vim.api.nvim_create_namespace("cfml_query_extra")

-- ─── Warna SQL (group khusus, tidak mengganggu bahasa lain) ─────────────
local function sql_colors()
	vim.api.nvim_set_hl(0, "CfmlSqlKeyword", { fg = "#BD93F9", italic = true })
	vim.api.nvim_set_hl(0, "CfmlSqlFunction", { fg = "#50fa7b" })
	vim.api.nvim_set_hl(0, "CfmlSqlNumber", { fg = "#8BE9FD" })
	vim.api.nvim_set_hl(0, "CfmlSqlString", { fg = "#f1fa8c" })
	vim.api.nvim_set_hl(0, "CfmlSqlComment", { fg = "#6272a4", italic = true })
end
sql_colors()
vim.api.nvim_create_autocmd("ColorScheme", { callback = sql_colors })

-- ─── Daftar keyword SQL ─────────────────────────────────────────────────
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

-- ─── Prioritas (makin besar makin menang; Treesitter = 100) ─────────────
local P = {
	sql = 250,
	sql_str = 252,
	sql_comment = 255,
	tag = 300,
	attr = 310,
	str = 320,
	hash = 330,
	hash_fn = 340,
	hash_str = 350,
	hash_punct = 360,
	comment = 400,
}

local function apply(buf)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local text = table.concat(lines, "\n")
	local lower = text:lower()

	-- offset awal tiap baris (0-based byte)
	local starts, off = {}, 0
	for i, l in ipairs(lines) do
		starts[i] = off
		off = off + #l + 1
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

	-- s dan e: 1-based, inklusif
	local function mark(s, e, hl, prio)
		local r1, c1 = pos(s - 1)
		local r2, c2 = pos(e)
		vim.api.nvim_buf_set_extmark(buf, ns, r1, c1, {
			end_row = r2,
			end_col = c2,
			hl_group = hl,
			priority = prio + 1000,
		})
	end

	local function in_ranges(ranges, n)
		for _, r in ipairs(ranges) do
			if n >= r[1] and n <= r[2] then
				return true
			end
		end
		return false
	end

	local init = 1
	while true do
		-- <cfquery ...> (bukan <cfqueryparam>)
		local qs, qs_end = lower:find("<cfquery%f[^%w_][^>]*>", init)
		if not qs then
			break
		end
		local qe = lower:find("</cfquery>", qs_end, true) or #text
		local r1, r2 = qs_end + 1, qe - 1

		-- 0) SQL dasar ------------------------------------------------------
		-- kata: keyword dan fungsi
		local p = r1
		while true do
			local s, e = text:find("[%a_][%w_]*", p)
			if not s or s > r2 then
				break
			end
			local w = text:sub(s, e):lower()
			if KW[w] then
				mark(s, e, "CfmlSqlKeyword", P.sql)
			elseif text:sub(e + 1, e + 1) == "(" then
				mark(s, e, "CfmlSqlFunction", P.sql)
			end
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

		-- string '...'
		p = r1
		while true do
			local s, e = text:find("'[^'\n]*'", p)
			if not s or s > r2 then
				break
			end
			mark(s, e, "CfmlSqlString", P.sql_str)
			p = e + 1
		end

		-- komentar SQL --
		p = r1
		while true do
			local s, e = text:find("%-%-[^\n]*", p)
			if not s or s > r2 then
				break
			end
			mark(s, e, "CfmlSqlComment", P.sql_comment)
			p = e + 1
		end

		-- 1) komentar CFML <!--- ... ---> -----------------------------------
		local comments = {}
		p = r1
		while true do
			local cs, ce = text:find("<!%-%-%-.-%-%-%->", p)
			if not cs or cs > r2 then
				break
			end
			mark(cs, ce, "@comment", P.comment)
			comments[#comments + 1] = { cs, ce }
			p = ce + 1
		end

		-- 2) tag CFML di luar komentar --------------------------------------
		p = r1
		while true do
			local ts, te = lower:find("</?cf[%w_]+[^>]*>", p)
			if not ts or ts > r2 then
				break
			end
			if not in_ranges(comments, ts) then
				local tag = text:sub(ts, te)

				-- seluruh tag: nama tag dan < >
				mark(ts, te, "@tag", P.tag)

				-- nama atribut (value=, cfsqltype=, list=)
				local ap = 1
				while true do
					local as, ae = tag:find("[%w_]+=", ap)
					if not as then
						break
					end
					mark(ts + as - 1, ts + ae - 2, "@tag.attribute", P.attr)
					ap = ae + 1
				end

				-- string "..." dan #...# di dalam string
				local sp = 1
				while true do
					local ss, se = tag:find('"[^"]*"', sp)
					if not ss then
						break
					end
					mark(ts + ss - 1, ts + se - 1, "@string", P.str)

					local sub = tag:sub(ss, se)
					local hp = 1
					while true do
						local hs, he = sub:find("#[^#]*#", hp)
						if not hs then
							break
						end
						mark(ts + ss - 1 + hs - 1, ts + ss - 1 + he - 1, "@variable", P.hash)
						hp = he + 1
					end

					sp = se + 1
				end
			end
			p = te + 1
		end

		-- 3) ekspresi #...# di luar komentar --------------------------------
		p = r1
		while true do
			local hs, he = text:find("#[^#\n]+#", p)
			if not hs or hs > r2 then
				break
			end
			if not in_ranges(comments, hs) then
				local expr = text:sub(hs, he)
				mark(hs, he, "@variable", P.hash)

				-- nama fungsi: sesuatu(
				local fp = 1
				while true do
					local fs, fe = expr:find("[%w_%.]+%(", fp)
					if not fs then
						break
					end
					mark(hs + fs - 1, hs + fe - 2, "@function", P.hash_fn)
					fp = fe + 1
				end

				-- string "..." di dalam ekspresi
				local sp = 1
				while true do
					local ss, se = expr:find('"[^"]*"', sp)
					if not ss then
						break
					end
					mark(hs + ss - 1, hs + se - 1, "@string", P.hash_str)
					sp = se + 1
				end

				-- tanda # pembuka dan penutup
				mark(hs, hs, "@punctuation.special", P.hash_punct)
				mark(he, he, "@punctuation.special", P.hash_punct)
			end
			p = he + 1
		end

		init = qe + 1
	end
end

vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "TextChanged", "InsertLeave" }, {
	pattern = { "*.cfc", "*.cfm" },
	callback = function(a)
		apply(a.buf)
	end,
})

-- terapkan juga ke buffer CFML yang sudah terbuka saat file ini dimuat
for _, b in ipairs(vim.api.nvim_list_bufs()) do
	local name = vim.api.nvim_buf_get_name(b)
	if name:match("%.cfc$") or name:match("%.cfm$") then
		apply(b)
	end
end
