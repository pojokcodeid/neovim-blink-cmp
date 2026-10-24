-- ~/.config/nvim/lua/custom/blink_dotenv.lua
-- Source blink.cmp native untuk variabel environment (.env), tanpa nvim-cmp.
--
-- Fitur:
--   * Root proyek otomatis (monorepo friendly), membaca .env, .env.local,
--     .env.development, dst. (file belakangan menimpa file sebelumnya)
--   * Kunci dari .env.example / .env.sample ikut disarankan
--   * Sisipan sadar bahasa: process.env.X, os.environ["X"], ${X}, %X%, dst.
--     Jika kursor sudah di dalam accessor, hanya nama yang disisipkan
--   * Nilai rahasia (TOKEN, SECRET, PASSWORD, ...) disamarkan di dokumentasi
--   * Cache berdasarkan mtime file (cepat)
--   * Diagnostik: peringatan untuk variabel yang dipakai tapi belum didefinisikan
--   * Saat mengedit file .env: saran kunci dari .env.example yang belum ada
--   * Perintah: :DotenvReload :DotenvToggleSecrets :DotenvPick :DotenvGoto

local uv = vim.uv or vim.loop

local M = {}

---------------------------------------------------------------------------
-- Konfigurasi
---------------------------------------------------------------------------
local cfg = {
	root_markers = { ".git", "package.json", "pyproject.toml", "Cargo.toml", "go.mod", "composer.json", "Gemfile" },
	load_shell = true, -- sertakan variabel dari environment shell
	shell_only_in_context = true, -- variabel shell hanya muncul setelah $, %, process.env., dst.
	include_examples = true, -- sertakan kunci dari .env.example / .env.sample
	smart_wrap = true, -- sisipan sadar bahasa (false = selalu nama saja)
	min_chars = 2, -- minimal karakter agar saran muncul di luar konteks
	show_values = true, -- tampilkan nilai di dokumentasi
	mask_secrets = true, -- samarkan nilai yang tampak rahasia
	secret_patterns = {
		"SECRET",
		"TOKEN",
		"PASSWORD",
		"PASSWD",
		"PRIVATE",
		"API_?KEY",
		"ACCESS_?KEY",
		"CREDENTIAL",
		"AUTH",
	},
	diagnostics = true, -- peringatan variabel tidak terdefinisi
	diagnostics_max_lines = 5000,
	ignore = { "NODE_ENV", "MODE", "DEV", "PROD", "SSR", "BASE_URL" }, -- tidak dianggap tak terdefinisi
}

---------------------------------------------------------------------------
-- Util
---------------------------------------------------------------------------
local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.INFO, { title = "dotenv" })
end

local function fmt(template)
	return function(key)
		return template:format(key)
	end
end

local function env_kind(name)
	if name == ".env" or name:match("^%.env%.") then
		if name:match("example") or name:match("sample") or name:match("template") or name:match("dist$") then
			return "example"
		end
		return "env"
	end
	return nil
end

local function env_rank(name)
	if name == ".env" then
		return 1
	end
	if name == ".env.local" then
		return 2
	end
	if name:match("%.local$") then
		return 4
	end
	return 3
end

local function is_env_file(bufnr)
	local name = vim.fs.basename(vim.api.nvim_buf_get_name(bufnr))
	return env_kind(name) ~= nil
end

local function find_root(bufnr)
	local name = vim.api.nvim_buf_get_name(bufnr or 0)
	local start = (name ~= "" and name) or (uv.cwd() .. "/_")
	local markers = {}
	for _, m in ipairs(cfg.root_markers) do
		markers[m] = true
	end
	local ok, root = pcall(vim.fs.root, start, function(n)
		return env_kind(n) ~= nil or markers[n] == true
	end)
	return (ok and root) or uv.cwd()
end

local function is_secret(key)
	if not cfg.mask_secrets then
		return false
	end
	local upper = key:upper()
	for _, p in ipairs(cfg.secret_patterns) do
		if upper:find(p) then
			return true
		end
	end
	return false
end

local function display(key, value)
	if not cfg.show_values then
		return "••••••••"
	end
	if value == "" then
		return "(kosong)"
	end
	if is_secret(key) then
		return "••••••••"
	end
	if #value > 100 then
		value = value:sub(1, 100) .. "…"
	end
	return value
end

---------------------------------------------------------------------------
-- Parser .env + cache
---------------------------------------------------------------------------
local file_cache = {}

local function parse_line(line)
	line = line:gsub("\r$", "")
	line = line:gsub("^%s+", "")
	if line == "" or line:sub(1, 1) == "#" then
		return nil
	end
	line = line:gsub("^export%s+", "")
	local key, rest = line:match("^([%a_][%w_]*)%s*=%s*(.*)$")
	if not key then
		return nil
	end
	local quote = rest:sub(1, 1)
	local value
	if quote == '"' or quote == "'" then
		value = rest:match("^" .. quote .. "(.-)" .. quote) or rest:sub(2)
	else
		value = vim.trim((rest:gsub("%s+#.*$", "")))
	end
	return key, value
end

local function parse_file(path)
	local st = uv.fs_stat(path)
	if not st or st.type ~= "file" then
		file_cache[path] = nil
		return {}
	end
	local stamp = ("%d:%d:%d"):format(st.mtime.sec, st.mtime.nsec, st.size)
	local cached = file_cache[path]
	if cached and cached.stamp == stamp then
		return cached.entries
	end

	local entries = {}
	local ok, iter = pcall(io.lines, path)
	if ok then
		local lnum = 0
		for line in iter do
			lnum = lnum + 1
			local key, value = parse_line(line)
			if key then
				entries[#entries + 1] = { key = key, value = value, line = lnum }
			end
		end
	end
	file_cache[path] = { stamp = stamp, entries = entries }
	return entries
end

local function load_project(root)
	local files = {}
	for name, t in vim.fs.dir(root) do
		if t == "file" or t == "link" then
			local kind = env_kind(name)
			if kind then
				files[#files + 1] = { name = name, path = root .. "/" .. name, kind = kind, rank = env_rank(name) }
			end
		end
	end
	table.sort(files, function(a, b)
		if a.rank ~= b.rank then
			return a.rank < b.rank
		end
		return a.name < b.name
	end)

	local defs, examples = {}, {}
	for _, f in ipairs(files) do
		local target = (f.kind == "example") and examples or defs
		for _, e in ipairs(parse_file(f.path)) do
			target[e.key] = target[e.key] or {}
			table.insert(target[e.key], { file = f.name, path = f.path, line = e.line, value = e.value })
		end
	end
	return { root = root, defs = defs, examples = examples, files = files }
end

-- gabungkan .env + example + shell menjadi satu peta
local function collect(project)
	local out = {}
	for key, list in pairs(project.defs) do
		out[key] = { kind = "env", defs = list, source = list[#list].file }
	end
	if cfg.include_examples then
		for key, list in pairs(project.examples) do
			local last = list[#list]
			if out[key] then
				out[key].example = last
			else
				out[key] = { kind = "example", example = last, source = last.file }
			end
		end
	end
	if cfg.load_shell then
		for key, value in pairs(uv.os_environ()) do
			if out[key] then
				out[key].shell = value
			else
				out[key] = { kind = "shell", shell = value, source = "shell" }
			end
		end
	end
	return out
end

local function visible(entry, special)
	if entry.kind == "shell" and cfg.shell_only_in_context and not special then
		return false
	end
	return true
end

local function build_doc(key, e)
	local lines = { ("**%s**"):format(key), "" }
	if e.defs then
		for i, d in ipairs(e.defs) do
			local mark = (#e.defs > 1 and i == #e.defs) and "  ← efektif" or ""
			lines[#lines + 1] = ("- `%s:%d` → `%s`%s"):format(d.file, d.line, display(key, d.value), mark)
		end
	end
	if e.example then
		lines[#lines + 1] = ("- `%s:%d` (contoh) → `%s`"):format(
			e.example.file,
			e.example.line,
			display(key, e.example.value)
		)
	end
	if e.shell then
		lines[#lines + 1] = ("- shell → `%s`"):format(display(key, e.shell))
	end
	return table.concat(lines, "\n")
end

---------------------------------------------------------------------------
-- Spesifikasi bahasa
--   ref      : fungsi pembungkus nama -> ekspresi akses variabel
--   starts   : pola (akhir baris) yang ikut diganti saat menyisipkan
--   contexts : pola yang berarti kursor sudah di dalam accessor (sisipkan nama saja)
--   uses     : pola (dengan 1 capture) untuk diagnostik
---------------------------------------------------------------------------
local langs = {}
local function def(fts, spec)
	for _, ft in ipairs(fts) do
		langs[ft] = spec
	end
end

local Q = "[\"']"

def({ "sh", "bash", "zsh", "dockerfile", "yaml" }, {
	ref = fmt("${%s}"),
	starts = { "%${?[%w_]*$" },
})

def({ "javascript", "javascriptreact", "typescript", "typescriptreact", "vue", "svelte", "astro" }, {
	ref = fmt("process.env.%s"),
	contexts = {
		"process%.env%.[%w_]*$",
		"import%.meta%.env%.[%w_]*$",
		"process%.env%[%s*" .. Q .. "[%w_]*$",
	},
	uses = {
		"process%.env%.([%a_][%w_]*)",
		"import%.meta%.env%.([%a_][%w_]*)",
		"process%.env%[%s*" .. Q .. "([%w_]+)" .. Q .. "%s*%]",
	},
})

def({ "python" }, {
	ref = fmt('os.environ["%s"]'),
	contexts = {
		"os%.environ%[%s*" .. Q .. "[%w_]*$",
		"os%.environ%.get%(%s*" .. Q .. "[%w_]*$",
		"os%.getenv%(%s*" .. Q .. "[%w_]*$",
	},
	uses = {
		"os%.environ%[%s*" .. Q .. "([%w_]+)" .. Q .. "%s*%]",
		"os%.environ%.get%(%s*" .. Q .. "([%w_]+)" .. Q,
		"os%.getenv%(%s*" .. Q .. "([%w_]+)" .. Q,
	},
})

def({ "lua" }, {
	ref = fmt('os.getenv("%s")'),
	contexts = { "os%.getenv%(%s*" .. Q .. "[%w_]*$" },
	uses = { "os%.getenv%(%s*" .. Q .. "([%w_]+)" .. Q },
})

def({ "go" }, {
	ref = fmt('os.Getenv("%s")'),
	contexts = {
		'os%.Getenv%(%s*"[%w_]*$',
		'os%.LookupEnv%(%s*"[%w_]*$',
	},
	uses = {
		'os%.Getenv%(%s*"([%w_]+)"',
		'os%.LookupEnv%(%s*"([%w_]+)"',
	},
})

def({ "rust" }, {
	ref = fmt('std::env::var("%s")'),
	contexts = {
		'env::var%(%s*"[%w_]*$',
		'env!%(%s*"[%w_]*$',
	},
	uses = {
		'env::var%(%s*"([%w_]+)"',
		'env::var_os%(%s*"([%w_]+)"',
		'env!%(%s*"([%w_]+)"',
	},
})

def({ "ruby" }, {
	ref = fmt('ENV["%s"]'),
	contexts = {
		"ENV%[%s*" .. Q .. "[%w_]*$",
		"ENV%.fetch%(%s*" .. Q .. "[%w_]*$",
	},
	uses = {
		"ENV%[%s*" .. Q .. "([%w_]+)" .. Q .. "%s*%]",
		"ENV%.fetch%(%s*" .. Q .. "([%w_]+)" .. Q,
	},
})

def({ "php" }, {
	ref = fmt("getenv('%s')"),
	contexts = {
		"getenv%(%s*" .. Q .. "[%w_]*$",
		"%$_ENV%[%s*" .. Q .. "[%w_]*$",
		"env%(%s*" .. Q .. "[%w_]*$",
	},
	uses = {
		"getenv%(%s*" .. Q .. "([%w_]+)" .. Q,
		"%$_ENV%[%s*" .. Q .. "([%w_]+)" .. Q,
	},
})

def({ "java", "kotlin" }, {
	ref = fmt('System.getenv("%s")'),
	contexts = { 'System%.getenv%(%s*"[%w_]*$' },
	uses = { 'System%.getenv%(%s*"([%w_]+)"' },
})

def({ "dosbatch" }, {
	ref = fmt("%%%s%%"),
	starts = { "%%[%w_]*$" },
})

def({ "ps1" }, {
	ref = fmt("$env:%s"),
	starts = { "%$env:[%w_]*$" },
})

-- return: start (1-based, bagian teks yang diganti), ref (nil = nama saja), special
local function plan(spec, before, ws)
	for _, pat in ipairs(spec.contexts or {}) do
		if before:find(pat) then
			return ws, nil, true
		end
	end
	for _, pat in ipairs(spec.starts or {}) do
		local s = before:find(pat)
		if s then
			return s, spec.ref, s < ws
		end
	end
	return ws, spec.ref, false
end

---------------------------------------------------------------------------
-- Source blink.cmp
---------------------------------------------------------------------------
local Source = {}
Source.__index = Source

function M.new(opts)
	if opts then
		cfg = vim.tbl_deep_extend("force", cfg, opts)
	end
	return setmetatable({}, Source)
end

function Source:enabled()
	return true
end

function Source:get_trigger_characters()
	return { "$", "%", ".", '"', "'", "(", "{" }
end

local function finish(callback, items)
	callback({ items = items or {}, is_incomplete_backward = false, is_incomplete_forward = false })
	return function() end
end

function Source:get_completions(ctx, callback)
	local bufnr = ctx.bufnr or vim.api.nvim_get_current_buf()
	local ft = vim.bo[bufnr].filetype
	local col = ctx.cursor[2]
	local row = ctx.cursor[1] - 1
	local before = ctx.line:sub(1, col)
	local ws = before:find("[%w_]*$")
	local word = before:sub(ws)

	local Kind = require("blink.cmp.types").CompletionItemKind
	local project = load_project(find_root(bufnr))
	local items = {}

	-- Mode: sedang mengedit file .env -> sarankan kunci dari file lain/.env.example
	if is_env_file(bufnr) then
		if before:find("=") or #word < 1 then
			return finish(callback)
		end

		local current = {}
		for _, l in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
			local k = l:match("^%s*export%s+([%a_][%w_]*)%s*=") or l:match("^%s*([%a_][%w_]*)%s*=")
			if k then
				current[k] = true
			end
		end
		local cur_path = vim.api.nvim_buf_get_name(bufnr)

		local seen = {}
		for _, tbl in ipairs({ project.examples, project.defs }) do
			for key, list in pairs(tbl) do
				if not current[key] and not seen[key] then
					local other
					for _, d in ipairs(list) do
						if d.path ~= cur_path then
							other = d
						end
					end
					if other then
						seen[key] = true
						items[#items + 1] = {
							label = key,
							kind = Kind.Variable,
							filterText = key,
							labelDetails = { description = other.file },
							textEdit = {
								newText = key .. "=",
								range = {
									start = { line = row, character = ws - 1 },
									["end"] = { line = row, character = col },
								},
							},
							documentation = {
								kind = "markdown",
								value = ("**%s**\n\n- `%s:%d` → `%s`"):format(
									key,
									other.file,
									other.line,
									display(key, other.value)
								),
							},
						}
					end
				end
			end
		end
		return finish(callback, items)
	end

	-- Mode: kode biasa
	local spec = langs[ft]
	local start, ref, special = ws, nil, false
	if spec and cfg.smart_wrap then
		start, ref, special = plan(spec, before, ws)
	end

	if not special and #word < cfg.min_chars then
		return finish(callback)
	end

	local all = collect(project)
	for key, e in pairs(all) do
		if visible(e, special) then
			local rank = (e.kind == "env" and 0) or (e.kind == "example" and 1) or 2
			local text = ref and ref(key) or key
			items[#items + 1] = {
				label = key,
				kind = (e.kind == "env" and Kind.Variable) or (e.kind == "example" and Kind.Field) or Kind.Constant,
				filterText = key,
				sortText = ("%d_%s"):format(rank, key),
				labelDetails = { description = e.source },
				textEdit = {
					newText = text,
					range = {
						start = { line = row, character = start - 1 },
						["end"] = { line = row, character = col },
					},
				},
				documentation = { kind = "markdown", value = build_doc(key, e) },
			}
		end
	end

	return finish(callback, items)
end

---------------------------------------------------------------------------
-- Diagnostik
---------------------------------------------------------------------------
local ns = vim.api.nvim_create_namespace("blink_dotenv")

local function refresh_diagnostics(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
		return
	end

	local spec = langs[vim.bo[bufnr].filetype]
	if not (cfg.diagnostics and spec and spec.uses) then
		vim.diagnostic.reset(ns, bufnr)
		return
	end
	if vim.api.nvim_buf_line_count(bufnr) > cfg.diagnostics_max_lines then
		return
	end

	local project = load_project(find_root(bufnr))
	if vim.tbl_isempty(project.defs) and vim.tbl_isempty(project.examples) then
		vim.diagnostic.reset(ns, bufnr)
		return
	end

	local shell = cfg.load_shell and uv.os_environ() or {}
	local ignore = {}
	for _, k in ipairs(cfg.ignore) do
		ignore[k] = true
	end

	local diags = {}
	for i, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
		for _, pat in ipairs(spec.uses) do
			local init = 1
			while true do
				local s, e, name = line:find(pat, init)
				if not s then
					break
				end
				init = e + 1
				if name and not (project.defs[name] or shell[name] or ignore[name]) then
					local only_example = project.examples[name] ~= nil
					diags[#diags + 1] = {
						lnum = i - 1,
						end_lnum = i - 1,
						col = s - 1,
						end_col = e,
						severity = only_example and vim.diagnostic.severity.INFO or vim.diagnostic.severity.WARN,
						source = "dotenv",
						message = only_example
								and ("%s hanya ada di file contoh (.env.example), belum di .env"):format(name)
							or ("%s tidak ditemukan di file .env maupun shell"):format(name),
					}
				end
			end
		end
	end
	vim.diagnostic.set(ns, bufnr, diags)
end

local function refresh_all()
	for _, b in ipairs(vim.api.nvim_list_bufs()) do
		refresh_diagnostics(b)
	end
end

---------------------------------------------------------------------------
-- Perintah
---------------------------------------------------------------------------
local function pick()
	local bufnr = vim.api.nvim_get_current_buf()
	local all = collect(load_project(find_root(bufnr)))
	local list = {}
	for key, e in pairs(all) do
		if visible(e, false) then
			list[#list + 1] = key
		end
	end
	table.sort(list)
	if #list == 0 then
		return notify("Tidak ada variabel ditemukan", vim.log.levels.WARN)
	end

	local spec = langs[vim.bo[bufnr].filetype]
	vim.ui.select(list, {
		prompt = "Variabel environment",
		format_item = function(k)
			return ("%s  (%s)"):format(k, all[k].source)
		end,
	}, function(choice)
		if not choice then
			return
		end
		local text = (spec and spec.ref) and spec.ref(choice) or choice
		vim.api.nvim_put({ text }, "c", true, true)
	end)
end

local function goto_def()
	local key = vim.fn.expand("<cword>")
	local project = load_project(find_root(0))
	local list = project.defs[key] or project.examples[key]
	if not list then
		return notify(key .. " tidak ditemukan di file .env", vim.log.levels.WARN)
	end
	local d = list[#list]
	vim.cmd.edit(vim.fn.fnameescape(d.path))
	vim.api.nvim_win_set_cursor(0, { d.line, 0 })
end

local did_setup = false

-- Opsional: panggil agar perintah dan diagnostik aktif.
function M.setup(opts)
	cfg = vim.tbl_deep_extend("force", cfg, opts or {})
	if did_setup then
		return
	end
	did_setup = true

	vim.api.nvim_create_user_command("DotenvReload", function()
		file_cache = {}
		refresh_all()
		notify("Cache dimuat ulang")
	end, { desc = "Muat ulang cache .env" })

	vim.api.nvim_create_user_command("DotenvToggleSecrets", function()
		cfg.mask_secrets = not cfg.mask_secrets
		notify(cfg.mask_secrets and "Nilai rahasia disamarkan" or "Nilai rahasia DITAMPILKAN", vim.log.levels.WARN)
	end, { desc = "Samarkan/tampilkan nilai rahasia" })

	vim.api.nvim_create_user_command("DotenvPick", pick, { desc = "Pilih & sisipkan variabel environment" })
	vim.api.nvim_create_user_command("DotenvGoto", goto_def, { desc = "Lompat ke definisi variabel di .env" })

	local group = vim.api.nvim_create_augroup("BlinkDotenv", { clear = true })
	vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
		group = group,
		callback = function(args)
			if args.event == "BufWritePost" and is_env_file(args.buf) then
				refresh_all()
			else
				refresh_diagnostics(args.buf)
			end
		end,
	})
end

return M
