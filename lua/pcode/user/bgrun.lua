-- bgrun.lua  (letakkan di ~/.config/nvim/lua/bgrun.lua)
-- Jalankan command di background dari Neovim. Butuh Neovim >= 0.10.
--
-- Commands:
--   :BgRun             -> prompt cwd -> prompt command -> pilih buka browser atau tidak
--   :BgList / :BgStatus-> status & history (floating window, auto refresh)
--   :BgLog [id]        -> lihat log (live / follow)
--   :BgStop [id|all]   -> stop job (seluruh process group)

local M = {}
local uv = vim.uv or vim.loop
local is_win = vim.fn.has("win32") == 1

local cfg = {
	max_history = 50, -- jumlah history yang disimpan
	kill_on_exit = true, -- stop semua job saat Neovim ditutup
	shell = nil, -- default: vim.o.shell
	shell_args = { "-c" }, -- mis. { "-l", "-c" } jika PATH (nvm, dll) tidak ketemu
	disable_tool_browser = true, -- set BROWSER=none agar CRA dsb tidak buka browser sendiri
}

local data_dir = vim.fn.stdpath("state") .. "/bgrun"
local log_dir = data_dir .. "/logs"
local hist_file = data_dir .. "/history.json"

local jobs, seq = {}, 0
local list_state = {}
local ns = vim.api.nvim_create_namespace("bgrun")
local L = vim.log.levels

local function notify(msg, lvl)
	vim.notify("[bgrun] " .. msg, lvl or L.INFO)
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function strip_ansi(s)
	s = s:gsub("\27%[[%d;?]*%a", "")
	s = s:gsub("\27%].-\7", "")
	return s
end

-- progress bar (\r): tampilkan hanya versi terakhir per baris
local function fix_cr(lines)
	for i, l in ipairs(lines) do
		if l:find("\r", 1, true) then
			lines[i] = l:match("[^\r]*$")
		end
	end
	return lines
end

local function fmt_duration(s)
	s = math.max(0, math.floor(s))
	if s >= 3600 then
		return ("%dh%02dm"):format(math.floor(s / 3600), math.floor((s % 3600) / 60))
	elseif s >= 60 then
		return ("%dm%02ds"):format(math.floor(s / 60), s % 60)
	end
	return s .. "s"
end

local function status_of(j)
	if j.status == "running" and j.stopping then
		return "stopping"
	end
	return j.status
end

local function job_label(j)
	return ("#%d [%s] %s  (%s)"):format(j.id, status_of(j), j.cmd, vim.fn.fnamemodify(j.cwd, ":~"))
end

local function find_job(id)
	for _, j in ipairs(jobs) do
		if j.id == id then
			return j
		end
	end
end

local function running_jobs()
	local r = {}
	for _, j in ipairs(jobs) do
		if j.status == "running" and j.pid then
			r[#r + 1] = j
		end
	end
	return r
end

-- Cari URL lokal (localhost / 127.x / 0.0.0.0 / [::]) di output; URL harus
-- diikuti whitespace supaya tidak terpotong di tengah chunk.
local function find_url(text)
	for raw in text:gmatch("https?://[^%s]+%f[%s]") do
		local url = raw:gsub("[%.,;:%)'\"]+$", "")
		local hostport = url:match("^https?://([^/?#]+)")
		if hostport then
			local host = hostport:match("^(%[.-%])") or hostport:match("^([^:]+)")
			if
				host == "localhost"
				or host == "0.0.0.0"
				or host == "[::]"
				or host == "[::1]"
				or host:match("^127%.")
				or host:match("%.localhost$")
			then
				url = url:gsub("//0%.0%.0%.0", "//localhost"):gsub("//%[::%]", "//localhost")
				return url
			end
		end
	end
end

local function open_url(url)
	if vim.ui.open then
		local _, err = vim.ui.open(url)
		if err then
			notify("Gagal membuka browser: " .. tostring(err), L.ERROR)
		end
		return
	end
	local cmd
	if is_win then
		cmd = { "cmd", "/c", "start", "", url }
	elseif vim.fn.has("mac") == 1 then
		cmd = { "open", url }
	else
		cmd = { "xdg-open", url }
	end
	vim.fn.jobstart(cmd, { detach = true })
end

---------------------------------------------------------------------------
-- Persistence
---------------------------------------------------------------------------
local FIELDS = { "id", "cmd", "cwd", "status", "pid", "started", "ended", "code", "url", "log", "browser" }

local function save()
	local out = {}
	for _, j in ipairs(jobs) do
		local t = {}
		for _, k in ipairs(FIELDS) do
			t[k] = j[k]
		end
		out[#out + 1] = t
	end
	local f = io.open(hist_file, "w")
	if f then
		f:write(vim.json.encode(out))
		f:close()
	end
end

local function load()
	local f = io.open(hist_file, "r")
	if not f then
		return
	end
	local raw = f:read("*a")
	f:close()
	local ok, data = pcall(vim.json.decode, raw)
	if not ok or type(data) ~= "table" then
		return
	end
	for _, j in ipairs(data) do
		if j.status == "running" then
			j.status = "unknown" -- sesi Neovim sebelumnya berakhir
		end
		j.pid = nil
		jobs[#jobs + 1] = j
		seq = math.max(seq, j.id or 0)
	end
end

local function trim()
	while #jobs > cfg.max_history do
		local idx
		for i, j in ipairs(jobs) do
			if j.status ~= "running" then
				idx = i
				break
			end
		end
		if not idx then
			break
		end
		os.remove(jobs[idx].log)
		table.remove(jobs, idx)
	end
end

---------------------------------------------------------------------------
-- Log buffer (live)
---------------------------------------------------------------------------
local function append_buf(buf, text)
	text = text:gsub("\r\n", "\n")
	local count = vim.api.nvim_buf_line_count(buf)
	local last = vim.api.nvim_buf_get_lines(buf, count - 1, count, false)[1] or ""
	local parts = vim.split(text, "\n", { plain = true })
	parts[1] = last .. parts[1]
	fix_cr(parts)

	local followers = {}
	for _, w in ipairs(vim.fn.win_findbuf(buf)) do
		if vim.api.nvim_win_get_cursor(w)[1] >= count then
			followers[#followers + 1] = w
		end
	end

	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, count - 1, count, false, parts)
	vim.bo[buf].modifiable = false

	local new_count = vim.api.nvim_buf_line_count(buf)
	for _, w in ipairs(followers) do
		pcall(vim.api.nvim_win_set_cursor, w, { new_count, 0 })
	end
end

-- Tulis ke file log + (jika buffer log terbuka) ke buffer.
local function emit(job, text)
	local f = io.open(job.log, "ab")
	if f then
		f:write(text)
		f:close()
	end
	job.bytes = (job.bytes or 0) + #text
	local upto = job.bytes
	vim.schedule(function()
		local buf = job.logbuf
		if buf and vim.api.nvim_buf_is_valid(buf) and upto > (job.loaded or 0) then
			job.loaded = upto
			append_buf(buf, strip_ansi(text))
		end
	end)
end

local function ensure_logbuf(job)
	if job.logbuf and vim.api.nvim_buf_is_valid(job.logbuf) then
		return job.logbuf
	end
	local raw = ""
	local f = io.open(job.log, "rb")
	if f then
		raw = f:read("*a")
		f:close()
	end
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].swapfile = false
	vim.bo[buf].bufhidden = "hide"
	vim.bo[buf].filetype = "log"
	local text = strip_ansi(raw):gsub("\r\n", "\n")
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, fix_cr(vim.split(text, "\n", { plain = true })))
	vim.bo[buf].modifiable = false
	pcall(vim.api.nvim_buf_set_name, buf, ("bgrun://%d %s"):format(job.id, job.cmd))
	job.loaded = #raw
	job.logbuf = buf
	return buf
end

---------------------------------------------------------------------------
-- Start / finish / stop
---------------------------------------------------------------------------
local function finish(job, code, signal)
	job.ended = os.time()
	job.code = code
	job.handle = nil
	if job.stopping then
		job.status = "stopped"
	elseif code == 0 and (signal or 0) == 0 then
		job.status = "done"
	else
		job.status = "failed"
	end
	local sig = (signal or 0) ~= 0 and (", signal " .. signal) or ""
	emit(
		job,
		("\n[%s | exit code %s%s | %s]\n"):format(
			job.status,
			tostring(code),
			sig,
			fmt_duration(job.ended - job.started)
		)
	)
	trim()
	save()
	local lvl = job.status == "failed" and L.WARN or L.INFO
	notify(("#%d `%s` -> %s (exit %s)"):format(job.id, job.cmd, job.status, tostring(code)), lvl)
end

local function start(cwd, cmd, browser)
	seq = seq + 1
	local job = {
		id = seq,
		cmd = cmd,
		cwd = cwd,
		browser = browser,
		status = "running",
		started = os.time(),
		log = ("%s/%d.log"):format(log_dir, seq),
	}
	local f = io.open(job.log, "wb")
	if f then
		f:close()
	end
	jobs[#jobs + 1] = job
	emit(job, ("$ %s\n# cwd   : %s\n# mulai : %s\n"):format(cmd, cwd, os.date("%Y-%m-%d %H:%M:%S", job.started)))

	-- stdin dibuat pipe yang tetap terbuka (tidak pernah EOF). Banyak dev server
	-- (react-scripts/CRA, dll) langsung exit kalau stdin tertutup (/dev/null).
	local stdin, stdout, stderr = uv.new_pipe(false), uv.new_pipe(false), uv.new_pipe(false)
	local shell = cfg.shell or vim.o.shell
	local args = vim.list_extend(vim.deepcopy(cfg.shell_args), { cmd })
	if is_win then
		shell, args = "cmd.exe", { "/c", cmd }
	end
	emit(job, ("# shell : %s %s\n\n"):format(shell, table.concat(cfg.shell_args, " ")))

	local env
	if cfg.disable_tool_browser then
		env = {}
		for k, v in pairs(vim.fn.environ()) do
			if k ~= "BROWSER" then
				env[#env + 1] = k .. "=" .. v
			end
		end
		env[#env + 1] = "BROWSER=none"
	end

	local handle, pid
	handle, pid = uv.spawn(shell, {
		args = args,
		cwd = cwd,
		env = env,
		stdio = { stdin, stdout, stderr },
		detached = not is_win, -- setsid -> satu process group, supaya bisa di-kill semua
		hide = true,
	}, function(code, signal)
		if handle and not handle:is_closing() then
			handle:close()
		end
		if not stdin:is_closing() then
			stdin:close()
		end
		vim.schedule(function()
			-- delay kecil supaya sisa output sempat ditulis sebelum footer
			vim.defer_fn(function()
				finish(job, code, signal)
			end, 250)
		end)
	end)

	if not handle then
		stdin:close()
		stdout:close()
		stderr:close()
		emit(job, "spawn error: " .. tostring(pid) .. "\n")
		vim.schedule(function()
			finish(job, -1, 0)
		end)
		return
	end

	job.handle, job.pid = handle, pid

	local acc = ""
	local function reader(pipe)
		pipe:read_start(function(err, data)
			if err or not data then
				if not pipe:is_closing() then
					pipe:close()
				end
				return
			end
			emit(job, data)
			if job.browser and not job.url then
				acc = (acc .. strip_ansi(data)):sub(-4096)
				local url = find_url(acc)
				if url then
					job.url = url
					vim.schedule(function()
						notify("Membuka " .. url)
						open_url(url)
						save()
					end)
				end
			end
		end)
	end
	reader(stdout)
	reader(stderr)

	trim()
	save()
	notify(("#%d started (pid %d): %s  [%s]"):format(job.id, pid, cmd, vim.fn.fnamemodify(cwd, ":~")))
end

local function kill_job(job, sig, sync)
	if not job.pid then
		return
	end
	if is_win then
		local p = vim.system({ "taskkill", "/PID", tostring(job.pid), "/T", "/F" })
		if sync then
			p:wait(2000)
		end
	else
		if not uv.kill(-job.pid, sig) then
			pcall(function()
				job.handle:kill(sig)
			end)
		end
	end
end

local function stop_job(job)
	if job.status ~= "running" then
		notify(("Job #%d tidak sedang berjalan (%s)"):format(job.id, job.status), L.WARN)
		return
	end
	if not job.pid then
		return
	end
	job.stopping = true
	kill_job(job, "sigterm")
	notify(("Stopping #%d `%s`..."):format(job.id, job.cmd))
	vim.defer_fn(function()
		if job.status == "running" then
			kill_job(job, "sigkill")
		end
	end, 3000)
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------
local function last_cmd_for(cwd)
	for i = #jobs, 1, -1 do
		if jobs[i].cwd == cwd then
			return jobs[i].cmd
		end
	end
	return ""
end

-- Prompt native (vim.fn.input / confirm): tidak bergantung plugin UI
-- (dressing / snacks / noice) yang kadang membatalkan prompt bersarang.
local function ask(prompt, default, completion)
	local ok, res = pcall(vim.fn.input, {
		prompt = prompt,
		default = default or "",
		completion = completion,
		cancelreturn = vim.NIL,
	})
	vim.cmd("redraw")
	if not ok or res == vim.NIL then
		return nil
	end
	res = vim.trim(res)
	return res ~= "" and res or nil
end

-- Start dengan error handling supaya kegagalan selalu terlihat.
function M.exec(cwd, cmd, browser)
	local ok, err = xpcall(start, debug.traceback, cwd, cmd, browser)
	if not ok then
		notify("Gagal menjalankan job:\n" .. tostring(err), L.ERROR)
	end
end

function M.run()
	local cwd = ask("Working directory: ", vim.fn.getcwd(), "dir")
	if not cwd then
		return
	end
	cwd = vim.fn.fnamemodify(vim.fn.expand(cwd), ":p")
	if #cwd > 1 and not cwd:match("^%a:[/\\]$") then
		cwd = cwd:gsub("[/\\]+$", "")
	end
	if vim.fn.isdirectory(cwd) == 0 then
		notify("Directory tidak ditemukan: " .. cwd, L.ERROR)
		return
	end

	local cmd = ask("Command: ", last_cmd_for(cwd), "shellcmd")
	if not cmd then
		return
	end

	local choice = vim.fn.confirm("Buka link di default browser?", "&Ya\n&Tidak", 2)
	if choice == 0 then
		return
	end
	M.exec(cwd, cmd, choice == 1)
end

function M.stop(arg)
	local running = running_jobs()
	if #running == 0 then
		notify("Tidak ada job yang sedang berjalan")
		return
	end
	if arg == "all" then
		for _, j in ipairs(running) do
			stop_job(j)
		end
		return
	end
	if arg and arg ~= "" then
		local j = find_job(tonumber(arg))
		if j then
			stop_job(j)
		else
			notify("Job #" .. arg .. " tidak ditemukan", L.WARN)
		end
		return
	end
	if #running == 1 then
		stop_job(running[1])
		return
	end
	local items = { "ALL" }
	for i = #running, 1, -1 do
		items[#items + 1] = running[i]
	end
	vim.ui.select(items, {
		prompt = "Stop job:",
		format_item = function(it)
			return it == "ALL" and "Stop semua job yang berjalan" or job_label(it)
		end,
	}, function(choice)
		if choice == "ALL" then
			for _, j in ipairs(running) do
				stop_job(j)
			end
		elseif choice then
			stop_job(choice)
		end
	end)
end

local function pick_job(arg, cb)
	if arg and arg ~= "" then
		local j = find_job(tonumber(arg))
		if j then
			cb(j)
		else
			notify("Job #" .. arg .. " tidak ditemukan", L.WARN)
		end
		return
	end
	if #jobs == 0 then
		notify("Belum ada history. Jalankan :BgRun")
		return
	end
	if #jobs == 1 then
		cb(jobs[1])
		return
	end
	local items = {}
	for i = #jobs, 1, -1 do
		items[#items + 1] = jobs[i]
	end
	vim.ui.select(items, { prompt = "Pilih job:", format_item = job_label }, function(j)
		if j then
			cb(j)
		end
	end)
end

function M.log(arg)
	pick_job(arg, function(job)
		local buf = ensure_logbuf(job)
		local existing = vim.fn.win_findbuf(buf)[1]
		if existing then
			vim.api.nvim_set_current_win(existing)
			return
		end
		vim.cmd("botright 15split")
		local win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_buf(win, buf)
		vim.wo[win].wrap = false
		vim.wo[win].number = false
		vim.wo[win].signcolumn = "no"
		vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(buf), 0 })
		vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, silent = true, desc = "Tutup log" })
	end)
end

---------------------------------------------------------------------------
-- Status / history window
---------------------------------------------------------------------------
local STATUS_HL = {
	running = "DiagnosticOk",
	stopping = "DiagnosticWarn",
	done = "DiagnosticHint",
	failed = "DiagnosticError",
	stopped = "DiagnosticWarn",
	unknown = "Comment",
}

local function render()
	local st = list_state
	if not (st.buf and vim.api.nvim_buf_is_valid(st.buf)) then
		return false
	end
	local now = os.time()
	local lines = {
		" ID    STATUS    MULAI        DURASI    EXIT  COMMAND  (CWD)",
		("─"):rep(vim.o.columns),
	}
	local marks = {}
	st.map = {}

	for i = #jobs, 1, -1 do
		local j = jobs[i]
		local status = status_of(j)
		local dur = (j.ended or j.status == "running") and fmt_duration((j.ended or now) - j.started) or "-"
		local line = (" %-5d %-9s %-12s %-9s %-5s %s  (%s)%s"):format(
			j.id,
			status,
			os.date("%d/%m %H:%M", j.started),
			dur,
			j.code ~= nil and tostring(j.code) or "-",
			j.cmd,
			vim.fn.fnamemodify(j.cwd, ":~"),
			j.url and ("  -> " .. j.url) or ""
		)
		lines[#lines + 1] = line
		st.map[#lines] = j
		marks[#marks + 1] = { #lines - 1, status }
	end
	if #jobs == 0 then
		lines[#lines + 1] = " (belum ada history — jalankan :BgRun)"
	end

	local cur
	if st.win and vim.api.nvim_win_is_valid(st.win) then
		cur = vim.api.nvim_win_get_cursor(st.win)
	end

	vim.bo[st.buf].modifiable = true
	vim.api.nvim_buf_set_lines(st.buf, 0, -1, false, lines)
	vim.bo[st.buf].modifiable = false

	vim.api.nvim_buf_clear_namespace(st.buf, ns, 0, -1)
	vim.api.nvim_buf_set_extmark(st.buf, ns, 0, 0, { line_hl_group = "Title" })
	for _, m in ipairs(marks) do
		vim.api.nvim_buf_set_extmark(st.buf, ns, m[1], 7, {
			end_col = 7 + #m[2],
			hl_group = STATUS_HL[m[2]] or "Normal",
		})
	end

	if cur and st.win and vim.api.nvim_win_is_valid(st.win) then
		cur[1] = math.min(math.max(cur[1], 3), #lines)
		pcall(vim.api.nvim_win_set_cursor, st.win, cur)
	end
	return true
end

function M.list()
	if list_state.win and vim.api.nvim_win_is_valid(list_state.win) then
		vim.api.nvim_set_current_win(list_state.win)
		return
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].swapfile = false
	list_state = { buf = buf, map = {} }
	render()

	local width = math.floor(vim.o.columns * 0.9)
	local height = math.min(math.max(#jobs + 4, 8), math.floor(vim.o.lines * 0.7))
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2) - 1,
		col = math.floor((vim.o.columns - width) / 2),
		style = "minimal",
		border = "rounded",
		title = " Background Jobs ",
		title_pos = "center",
		footer = " <CR> log   s stop   o browser   r rerun   x hapus   q tutup ",
		footer_pos = "center",
	})
	list_state.win = win
	vim.wo[win].cursorline = true
	vim.wo[win].wrap = false
	pcall(vim.api.nvim_win_set_cursor, win, { math.min(3, vim.api.nvim_buf_line_count(buf)), 0 })

	local function cur_job()
		return list_state.map[vim.api.nvim_win_get_cursor(win)[1]]
	end
	local function close()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end
	local function map(lhs, fn, desc)
		vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, silent = true, desc = desc })
	end

	map("q", close, "Tutup")
	map("<Esc>", close, "Tutup")

	local function open_log()
		local j = cur_job()
		if j then
			close()
			M.log(tostring(j.id))
		end
	end
	map("<CR>", open_log, "Lihat log")
	map("l", open_log, "Lihat log")

	map("s", function()
		local j = cur_job()
		if j then
			stop_job(j)
		end
	end, "Stop job")

	map("o", function()
		local j = cur_job()
		if not j then
			return
		end
		if j.url then
			open_url(j.url)
		else
			notify("Belum ada URL terdeteksi untuk job #" .. j.id, L.WARN)
		end
	end, "Buka URL di browser")

	map("r", function()
		local j = cur_job()
		if j then
			start(j.cwd, j.cmd, j.browser)
			render()
		end
	end, "Jalankan ulang")

	map("x", function()
		local j = cur_job()
		if not j then
			return
		end
		if j.status == "running" then
			notify("Stop job dulu sebelum dihapus", L.WARN)
			return
		end
		if j.logbuf and vim.api.nvim_buf_is_valid(j.logbuf) then
			vim.api.nvim_buf_delete(j.logbuf, { force = true })
		end
		os.remove(j.log)
		for i, x in ipairs(jobs) do
			if x == j then
				table.remove(jobs, i)
				break
			end
		end
		save()
		render()
	end, "Hapus dari history")

	-- auto refresh tiap 1 detik selama window terbuka
	local timer = uv.new_timer()
	timer:start(
		1000,
		1000,
		vim.schedule_wrap(function()
			if not render() and not timer:is_closing() then
				timer:stop()
				timer:close()
			end
		end)
	)
end

---------------------------------------------------------------------------
-- Setup
---------------------------------------------------------------------------
local did_setup = false

function M.setup(opts)
	cfg = vim.tbl_deep_extend("force", cfg, opts or {})
	if did_setup then
		return
	end
	did_setup = true

	vim.fn.mkdir(log_dir, "p")
	load()

	local function ids()
		local r = {}
		for i = #jobs, 1, -1 do
			r[#r + 1] = tostring(jobs[i].id)
		end
		return r
	end

	-- :BgRun            -> prompt interaktif
	-- :BgRun npm start  -> langsung jalan di cwd saat ini (tanpa browser)
	-- :BgRun! npm start -> sama, tapi buka URL di default browser
	vim.api.nvim_create_user_command("BgRun", function(o)
		if o.args ~= "" then
			M.exec(vim.fn.getcwd(), o.args, o.bang)
		else
			M.run()
		end
	end, { nargs = "*", bang = true, complete = "shellcmd", desc = "Jalankan command di background" })

	vim.api.nvim_create_user_command("BgList", function()
		M.list()
	end, { desc = "Status & history background job" })

	vim.api.nvim_create_user_command("BgStatus", function()
		M.list()
	end, { desc = "Status & history background job" })

	vim.api.nvim_create_user_command("BgLog", function(o)
		M.log(o.args)
	end, { nargs = "?", complete = ids, desc = "Lihat log background job" })

	vim.api.nvim_create_user_command("BgStop", function(o)
		M.stop(o.args)
	end, {
		nargs = "?",
		complete = function()
			local r = { "all" }
			for _, j in ipairs(running_jobs()) do
				r[#r + 1] = tostring(j.id)
			end
			return r
		end,
		desc = "Stop background job",
	})

	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = vim.api.nvim_create_augroup("BgRun", { clear = true }),
		callback = function()
			if cfg.kill_on_exit then
				for _, j in ipairs(running_jobs()) do
					j.stopping = true
					kill_job(j, "sigterm", true)
					j.status, j.ended = "stopped", os.time()
				end
			end
			save()
		end,
	})
end

return M
