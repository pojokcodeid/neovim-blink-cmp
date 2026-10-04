return {
	"nvimtools/none-ls.nvim",
	dependencies = { "nvim-lua/plenary.nvim" },
	ft = { "cfml", "cfscript" },
	config = function()
		require("null-ls").setup({})
		-- lua/cflint_actions.lua
		-- Quick fix untuk diagnostic CFLint (MISSING_VAR) lewat none-ls (code action).
		--
		-- Yang ditangani:
		--   1. x = ...            -> var x = ...
		--   2. for (i = 1; ...)   -> for (var i = 1; ...)
		--   3. x.key = ...        -> tambah `var x = {};` di awal function
		--      x["key"] = ...        (x[1] = ... -> `var x = [];`)
		--   4. cfloop(index="x")  -> index="local.x" dan semua pemakaian x di blok loop
		--                            menjadi local.x

		local null_ls = require("null-ls")

		-- Set true kalau ingin buffer otomatis disimpan setelah fix
		-- (box cflint membaca file di disk, bukan isi buffer).
		local AUTO_SAVE = false

		----------------------------------------------------------------------
		-- Util
		----------------------------------------------------------------------

		local function parse_missing_var(d)
			local msg = d.message or ""
			if not msg:find("MISSING_VAR", 1, true) then
				return nil
			end
			return msg:match("Variable%s+([%w_%.]+)%s+is not declared")
		end

		-- buang isi string sederhana agar { } di dalam string tidak ikut terhitung
		local function strip_strings(s)
			s = s:gsub('"[^"]*"', "")
			s = s:gsub("'[^']*'", "")
			return s
		end

		local function relint(bufnr)
			vim.defer_fn(function()
				if AUTO_SAVE and vim.api.nvim_buf_is_valid(bufnr) then
					vim.api.nvim_buf_call(bufnr, function()
						vim.cmd("silent! write")
					end)
				end
				require("lint").try_lint()
			end, 100)
		end

		----------------------------------------------------------------------
		-- Cari function yang melingkupi from_lnum (semua 0-based)
		-- return: baris "function", baris "{" pembuka (-1 jika tidak ada), baris "}" penutup
		----------------------------------------------------------------------
		local function find_function_range(lines, from_lnum)
			for i = from_lnum, 0, -1 do
				local l = lines[i + 1]
				if l and l:find("function%s*[%w_]*%s*%(") then
					local body_open
					for j = i, math.min(i + 8, #lines - 1) do
						if lines[j + 1]:find("{", 1, true) then
							body_open = j
							break
						end
					end
					if body_open then
						local depth = 0
						for k = body_open, #lines - 1 do
							local s = strip_strings(lines[k + 1])
							local _, opens = s:gsub("{", "")
							local _, closes = s:gsub("}", "")
							depth = depth + opens - closes
							if depth <= 0 and closes > 0 then
								if k >= from_lnum then
									return i, body_open, k
								end
								break -- function ini selesai sebelum from_lnum, cari yang lebih luar
							end
						end
					end
				end
			end
			return 0, -1, #lines - 1
		end

		----------------------------------------------------------------------
		-- Deteksi assignment ke isi variabel: return "{}" / "[]" / nil
		----------------------------------------------------------------------
		local function detect_container(l, esc)
			-- name.key = ...
			if l:match("^%s*" .. esc .. "%.[^=%s]+%s*=[^=]") then
				return "{}"
			end
			-- name["key"] = ...
			if l:match("^%s*" .. esc .. "%[%s*[\"'][^\"']*[\"']%s*%]%s*=[^=]") then
				return "{}"
			end
			-- name[1] = ... / name[i] = ...
			if l:match("^%s*" .. esc .. "%[[^%]]+%]%s*=[^=]") then
				return "[]"
			end
			return nil
		end

		----------------------------------------------------------------------
		-- Tentukan jenis fix untuk variabel `name`
		--   { kind = "inline", l, c }        -> sisipkan "var " di (l, c)
		--   { kind = "struct", l, init }     -> sisipkan baris "var name = {};" setelah baris l
		--   nil                              -> sudah dideklarasikan
		----------------------------------------------------------------------
		local function resolve_fix(bufnr, name, from_lnum, from_col)
			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			local fstart, body_open, fend = find_function_range(lines, from_lnum)
			local esc = vim.pesc(name)
			local decl_pat = "var%s+" .. esc .. "[%s=;]"

			local first_simple, first_struct, struct_init = nil, nil, "{}"

			for i = math.max(fstart, 0), fend do
				local l = lines[i + 1]
				if l then
					if l:match(decl_pat) then
						return nil
					end

					if not first_struct then
						local init = detect_container(l, esc)
						if init then
							first_struct, struct_init = i, init
						end
					end

					if not first_simple then
						local init = 1
						while true do
							local s, e = l:find(name, init, true)
							if not s then
								break
							end
							local before = l:sub(1, s - 1)
							local after = l:sub(e + 1)
							local boundary_ok = not before:sub(-1):match("[%w_%.]")
							if
								boundary_ok
								and after:match("^%s*=[^=]")
								and not before:match("var%s+$")
								and not before:match("local%.$")
							then
								first_simple = { l = i, c = s - 1 }
								break
							end
							init = e + 1
						end
					end
				end
			end

			-- yang muncul lebih dulu menentukan jenis deklarasi
			if first_simple and (not first_struct or first_simple.l <= first_struct) then
				return { kind = "inline", l = first_simple.l, c = first_simple.c }
			end
			if first_struct then
				local at = body_open >= 0 and body_open or (first_struct - 1)
				return { kind = "struct", l = at, init = struct_init }
			end

			return { kind = "inline", l = from_lnum, c = from_col }
		end

		local function apply_fix(bufnr, name, fix)
			if not fix then
				return false
			end

			if fix.kind == "inline" then
				local line = vim.api.nvim_buf_get_lines(bufnr, fix.l, fix.l + 1, false)[1]
				if not line then
					return false
				end
				if line:sub(fix.c + 1, fix.c + #name) ~= name then
					return false
				end
				if line:sub(1, fix.c):match("var%s+$") then
					return false
				end
				vim.api.nvim_buf_set_text(bufnr, fix.l, fix.c, fix.l, fix.c, { "var " })
				return true
			end

			-- struct / array: baris baru di awal body function
			local nxt = vim.api.nvim_buf_get_lines(bufnr, fix.l + 1, fix.l + 2, false)[1] or ""
			local indent = nxt:match("^(%s*)") or ""
			if indent == "" then
				local cur = vim.api.nvim_buf_get_lines(bufnr, math.max(fix.l, 0), math.max(fix.l, 0) + 1, false)[1]
					or ""
				indent = (cur:match("^(%s*)") or "") .. "\t"
			end
			vim.api.nvim_buf_set_lines(
				bufnr,
				fix.l + 1,
				fix.l + 1,
				false,
				{ indent .. "var " .. name .. " = " .. (fix.init or "{}") .. ";" }
			)
			return true
		end

		----------------------------------------------------------------------
		-- Variabel loop: cfloop(index = "x") / cfloop(item = "x")
		----------------------------------------------------------------------
		local function is_loop_var(line, name)
			local n = vim.pesc(name)
			return line:match("index%s*=%s*[\"']" .. n .. "[\"']") ~= nil
				or line:match("item%s*=%s*[\"']" .. n .. "[\"']") ~= nil
		end

		-- Ganti `name` (kata utuh, di luar string, belum ber-prefix) menjadi `local.name`
		local function localize_in_line(line, name)
			local out, i, n = {}, 1, #line
			local in_str = nil
			while i <= n do
				local ch = line:sub(i, i)
				if in_str then
					table.insert(out, ch)
					if ch == in_str then
						in_str = nil
					end
					i = i + 1
				elseif ch == '"' or ch == "'" then
					in_str = ch
					table.insert(out, ch)
					i = i + 1
				elseif line:sub(i, i + #name - 1) == name then
					local prev = line:sub(i - 1, i - 1)
					local nxt = line:sub(i + #name, i + #name)
					local ok_prev = (i == 1) or not prev:match("[%w_%.]")
					local ok_next = not nxt:match("[%w_]")
					if ok_prev and ok_next then
						table.insert(out, "local." .. name)
						i = i + #name
					else
						table.insert(out, ch)
						i = i + 1
					end
				else
					table.insert(out, ch)
					i = i + 1
				end
			end
			return table.concat(out)
		end

		-- Akhir blok { ... } yang dibuka pada baris lnum
		local function find_block_end(lines, lnum)
			local depth, started = 0, false
			for k = lnum, #lines - 1 do
				local s = strip_strings(lines[k + 1])
				local _, o = s:gsub("{", "")
				local _, c = s:gsub("}", "")
				if o > 0 then
					started = true
				end
				depth = depth + o - c
				if started and depth <= 0 then
					return k
				end
			end
			return lnum
		end

		local function fix_loop_var(bufnr, name, lnum)
			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			local first = lines[lnum + 1]
			if not first or not is_loop_var(first, name) then
				return false
			end

			local last = find_block_end(lines, lnum)
			for k = lnum, last do
				lines[k + 1] = localize_in_line(lines[k + 1], name)
			end

			-- atribut index="x" ada di dalam string, ubah khusus di baris pertama
			local n = vim.pesc(name)
			local l1 = lines[lnum + 1]
			l1 = l1:gsub("(index%s*=%s*[\"'])" .. n .. "([\"'])", "%1local." .. name .. "%2")
			l1 = l1:gsub("(item%s*=%s*[\"'])" .. n .. "([\"'])", "%1local." .. name .. "%2")
			lines[lnum + 1] = l1

			vim.api.nvim_buf_set_lines(bufnr, lnum, last + 1, false, vim.list_slice(lines, lnum + 1, last + 1))
			return true
		end

		----------------------------------------------------------------------
		-- Satu diagnostic -> satu fix
		----------------------------------------------------------------------
		local function fix_single(bufnr, name, d)
			local line = vim.api.nvim_buf_get_lines(bufnr, d.lnum, d.lnum + 1, false)[1] or ""
			if is_loop_var(line, name) then
				fix_loop_var(bufnr, name, d.lnum)
			else
				apply_fix(bufnr, name, resolve_fix(bufnr, name, d.lnum, d.col))
			end
		end

		local function fix_all(bufnr, all)
			-- 1) variabel loop dulu (jumlah baris tidak berubah)
			local handled = {}
			for _, item in ipairs(all) do
				local line = vim.api.nvim_buf_get_lines(bufnr, item.d.lnum, item.d.lnum + 1, false)[1] or ""
				if is_loop_var(line, item.name) then
					fix_loop_var(bufnr, item.name, item.d.lnum)
					handled[item] = true
				end
			end

			-- 2) sisanya: hitung semua fix sebelum buffer berubah, lalu dedupe
			local fixes, seen = {}, {}
			for _, item in ipairs(all) do
				if not handled[item] then
					local fix = resolve_fix(bufnr, item.name, item.d.lnum, item.d.col)
					if fix then
						local key = fix.kind .. ":" .. fix.l .. ":" .. (fix.c or 0) .. ":" .. item.name
						if not seen[key] then
							seen[key] = true
							table.insert(fixes, { fix = fix, name = item.name })
						end
					end
				end
			end

			-- terapkan dari bawah ke atas (dan kanan ke kiri) agar posisi tidak bergeser
			table.sort(fixes, function(a, b)
				if a.fix.l ~= b.fix.l then
					return a.fix.l > b.fix.l
				end
				return (a.fix.c or 0) > (b.fix.c or 0)
			end)
			for _, f in ipairs(fixes) do
				apply_fix(bufnr, f.name, f.fix)
			end
		end

		----------------------------------------------------------------------
		-- Register ke none-ls
		----------------------------------------------------------------------
		null_ls.register({
			name = "cflint-quickfix",
			method = null_ls.methods.CODE_ACTION,
			filetypes = { "cfml", "cfc" }, -- samakan dengan `:set ft?`
			generator = {
				fn = function(params)
					local actions = {}
					local bufnr = params.bufnr

					-- Aksi untuk baris kursor
					for _, d in ipairs(vim.diagnostic.get(bufnr, { lnum = params.row - 1 })) do
						local name = parse_missing_var(d)
						if name then
							table.insert(actions, {
								title = "Fix MISSING_VAR: " .. name,
								action = function()
									fix_single(bufnr, name, d)
									relint(bufnr)
								end,
							})
						end
					end

					-- Fix all (hanya muncul kalau ada yang bisa diperbaiki)
					local all = {}
					for _, d in ipairs(vim.diagnostic.get(bufnr)) do
						local name = parse_missing_var(d)
						if name then
							table.insert(all, { d = d, name = name })
						end
					end

					if #all > 0 then
						table.insert(actions, {
							title = string.format("Fix all MISSING_VAR in file (%d)", #all),
							action = function()
								fix_all(bufnr, all)
								relint(bufnr)
							end,
						})
					end

					return actions
				end,
			},
		})
	end,
}
