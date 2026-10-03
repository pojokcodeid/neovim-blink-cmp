return {
	"nickjvandyke/opencode.nvim",
	-- Anda memakai OpenCode v2, jadi biarkan default (main).
	-- Kalau suatu saat pakai v1, aktifkan:
	-- version = "*",
	event = "VeryLazy",
	config = function()
		---------------------------------------------------------------------------
		-- Pengaturan
		---------------------------------------------------------------------------
		local settings = {
			auto_open = true, -- buka terminal otomatis saat ask/select
			width_ratio = 0.4, -- lebar split terminal (40% layar)
			notify_status = false, -- notifikasi status sesi
			debug = false, -- tampilkan semua event OpenCode (untuk debugging)
		}

		---------------------------------------------------------------------------
		-- Helper: kelola terminal OpenCode (split kanan + toggle)
		---------------------------------------------------------------------------
		local TERM_PATTERN = "^term://.*opencode"

		local function find_buf()
			for _, buf in ipairs(vim.api.nvim_list_bufs()) do
				if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf):match(TERM_PATTERN) then
					return buf
				end
			end
		end

		local function find_win()
			local buf = find_buf()
			if not buf then
				return
			end
			for _, win in ipairs(vim.api.nvim_list_wins()) do
				if vim.api.nvim_win_get_buf(win) == buf then
					return win
				end
			end
		end

		local function set_width()
			vim.api.nvim_win_set_width(0, math.floor(vim.o.columns * settings.width_ratio))
		end

		-- Buka terminal baru (dipakai juga oleh plugin sebagai server.start)
		local function start()
			local cur = vim.api.nvim_get_current_win()
			vim.cmd("botright vsplit term://opencode")
			set_width()
			vim.api.nvim_set_current_win(cur) -- fokus tetap di editor
		end

		-- Tampilkan terminal yang sudah ada tanpa mengambil fokus
		local function show()
			local buf = find_buf()
			if not buf or find_win() then
				return
			end
			local cur = vim.api.nvim_get_current_win()
			vim.cmd("botright vsplit")
			vim.api.nvim_win_set_buf(0, buf)
			set_width()
			vim.api.nvim_set_current_win(cur)
		end

		-- Pastikan terminal terlihat: tampilkan kalau tersembunyi, buat kalau belum ada
		local function ensure_visible()
			if find_win() then
				return
			end
			if find_buf() then
				show()
			else
				start()
			end
		end

		local function focus_terminal()
			local w = find_win()
			if w then
				vim.api.nvim_set_current_win(w)
				vim.cmd("startinsert")
			end
		end

		local function toggle()
			local win = find_win()
			if win then
				vim.api.nvim_win_close(win, false) -- sembunyikan, proses tetap jalan
			else
				ensure_visible()
				focus_terminal()
			end
		end

		---------------------------------------------------------------------------
		-- Opsi plugin
		---------------------------------------------------------------------------
		---@type opencode.Opts
		vim.g.opencode_opts = {
			server = {
				start = start,
			},
		}

		-- Agar buffer ikut ter-reload saat OpenCode mengedit file
		vim.o.autoread = true

		---------------------------------------------------------------------------
		-- Keymaps
		---------------------------------------------------------------------------
		local map = vim.keymap.set

		map({ "n", "x" }, "<leader>o", "", { desc = "OpenCode" })
		map({ "n", "x" }, "<leader>oa", function()
			if settings.auto_open then
				ensure_visible()
			end
			require("opencode").ask("@this: ")
		end, { desc = "OpenCode: Ask" })

		map({ "n", "x" }, "<leader>oo", function()
			if settings.auto_open then
				ensure_visible()
			end
			require("opencode").select()
		end, { desc = "OpenCode: Select" })

		map({ "n", "x" }, "go", function()
			return require("opencode").operator("@this")
		end, { desc = "OpenCode: Send range", expr = true })

		map("n", "goo", function()
			return require("opencode").operator("@this") .. "_"
		end, { desc = "OpenCode: Send line", expr = true })

		map({ "n", "t" }, "<C-.>", toggle, { desc = "OpenCode: Toggle terminal" })

		---------------------------------------------------------------------------
		-- Autocommands
		---------------------------------------------------------------------------
		local group = vim.api.nvim_create_augroup("OpencodeIntegration", { clear = true })

		-- 1. Buka/tampilkan terminal otomatis saat OpenCode mulai bekerja
		vim.api.nvim_create_autocmd("User", {
			group = group,
			pattern = "OpencodeEvent:session.execution.started",
			callback = ensure_visible,
			desc = "Show OpenCode terminal when execution starts",
		})

		-- 2. Debug + notifikasi status sesi
		vim.api.nvim_create_autocmd("User", {
			group = group,
			pattern = "OpencodeEvent:*",
			callback = function(args)
				---@type opencode.server.Event
				local event = args.data.event
				if settings.debug then
					vim.notify(vim.inspect(event), vim.log.levels.DEBUG)
				end
				if settings.notify_status and event.type == "session.status" then
					vim.notify("OpenCode: " .. event.data.status.type, vim.log.levels.INFO)
				end
			end,
			desc = "Debug / notify OpenCode events",
		})

		-- 3. Reload otomatis buffer yang berubah di disk
		vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI", "TermLeave" }, {
			group = group,
			callback = function()
				if vim.fn.mode() ~= "c" and vim.fn.getcmdwintype() == "" then
					vim.cmd("checktime")
				end
			end,
			desc = "Reload buffers changed by OpenCode",
		})

		-- 4. Beri tahu saat buffer di-reload
		vim.api.nvim_create_autocmd("FileChangedShellPost", {
			group = group,
			callback = function(args)
				vim.notify("Reloaded: " .. vim.fn.fnamemodify(args.file, ":~:."), vim.log.levels.INFO)
			end,
			desc = "Notify when a buffer is reloaded from disk",
		})

		-- 5. Tampilan terminal OpenCode lebih bersih + <C-q> untuk keluar terminal-mode
		vim.api.nvim_create_autocmd("TermOpen", {
			group = group,
			callback = function(args)
				if not vim.api.nvim_buf_get_name(args.buf):match(TERM_PATTERN) then
					return
				end
				vim.opt_local.number = false
				vim.opt_local.relativenumber = false
				vim.opt_local.signcolumn = "no"
				vim.opt_local.scrolloff = 0
				vim.keymap.set("t", "<C-q>", [[<C-\><C-n>]], { buffer = args.buf, desc = "Exit terminal mode" })
			end,
			desc = "Tweak OpenCode terminal buffer",
		})

		-- 6. Masuk insert-mode saat fokus ke terminal OpenCode
		--    (dijadwalkan + dicek, agar tidak "bocor" ke editor saat terminal dibuka tanpa fokus)
		vim.api.nvim_create_autocmd("BufEnter", {
			group = group,
			pattern = "term://*opencode*",
			callback = function(args)
				vim.schedule(function()
					if vim.api.nvim_get_current_buf() == args.buf and vim.bo[args.buf].buftype == "terminal" then
						vim.cmd("startinsert")
					end
				end)
			end,
			desc = "Auto-enter terminal mode on OpenCode buffer",
		})

		vim.api.nvim_create_user_command("OpencodeKill", function()
			local buf = find_buf()
			if not buf then
				vim.notify("Terminal OpenCode tidak ditemukan")
				return
			end
			local job = vim.b[buf].terminal_job_id
			if job then
				pcall(vim.fn.jobstop, job)
			end
			vim.api.nvim_buf_delete(buf, { force = true })
		end, { desc = "Kill OpenCode terminal" })

		---------------------------------------------------------------------------
		-- User commands (opsional)
		---------------------------------------------------------------------------
		vim.api.nvim_create_user_command("OpencodeToggle", toggle, { desc = "Toggle OpenCode terminal" })
		vim.api.nvim_create_user_command("OpencodeDebug", function()
			settings.debug = not settings.debug
			vim.notify("OpenCode debug: " .. tostring(settings.debug))
		end, { desc = "Toggle OpenCode event debug" })
	end,
}
