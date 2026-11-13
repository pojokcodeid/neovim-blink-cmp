-- install luarock
-- sudo apt-get install luarocks lua5.4 (untuk linux)
-- https://github.com/luarocks/luarocks/wiki/Installation-instructions-for-Windows

-- manual penggunaan
-- https://www.jetbrains.com/help/idea/exploring-http-syntax.html

return {
	"rest-nvim/rest.nvim",
	ft = "http",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-treesitter/nvim-treesitter",
	},
	init = function()
		vim.g.rest_nvim = {
			request = {
				skip_ssl_verification = false,
				hooks = {
					encode_url = true,
					set_content_type = true,
				},
			},
			response = {
				hooks = {
					decode_url = true,
					-- Dimatikan: format JSON sudah ditangani watcher jq di bawah,
					-- supaya dua formatter tidak mengubah buffer hasil yang sama.
					format = false,
				},
			},
			env = {
				enable = true,
				pattern = ".*%.env.*",
			},
			ui = {
				winbar = true,
				keybinds = {
					prev = "H", -- pindah tab: Response / Headers / Cookies
					next = "L",
				},
			},
			highlight = {
				enable = true,
				timeout = 250,
			},
			-- Dipanggil di file .http sebagai {{$accessToken}} / {{$refreshToken}}
			custom_dynamic_variables = {
				accessToken = function()
					return vim.g.accessToken or ""
				end,
				refreshToken = function()
					return vim.g.refreshToken or ""
				end,
			},
		}
	end,
	config = function()
		local group = vim.api.nvim_create_augroup("RestNvimCustom", { clear = true })

		-- Jaga tree-sitter tree buffer .http tetap segar setelah edit
		vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave" }, {
			group = group,
			pattern = "*.http",
			callback = function(ev)
				pcall(function()
					vim.treesitter.get_parser(ev.buf, "http"):parse(true)
				end)
			end,
		})

		local function format_json_body(buf)
			if not vim.api.nvim_buf_is_valid(buf) or vim.fn.executable("jq") == 0 then
				return
			end
			local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
			local s, e
			for i, l in ipairs(lines) do
				if l:match("^# @_RES") then
					s = i
				elseif l:match("^# @_END") then
					e = i
				end
			end
			if not s or not e or e - s < 2 then
				return
			end
			local body = table.concat(vim.list_slice(lines, s + 1, e - 1), "\n")
			local out = vim.fn.systemlist({ "jq", "." }, body)
			if vim.v.shell_error ~= 0 then
				return -- bukan JSON valid
			end
			local was_modifiable = vim.bo[buf].modifiable
			vim.bo[buf].modifiable = true
			vim.api.nvim_buf_set_lines(buf, s, e - 1, false, out)
			vim.bo[buf].modifiable = was_modifiable
			vim.bo[buf].modified = false
		end

		vim.api.nvim_create_autocmd("FileType", {
			group = group,
			pattern = "rest_nvim_result",
			callback = function(ev)
				local buf = ev.buf
				vim.wo.wrap = true
				vim.wo.linebreak = true
				vim.wo.conceallevel = 0

				vim.keymap.set("n", "<leader>jf", function()
					format_json_body(buf)
				end, { buffer = buf, desc = "Format JSON response" })

				-- pasang watcher sekali per buffer
				if vim.b[buf].json_watcher then
					return
				end
				vim.b[buf].json_watcher = true

				local pending = false
				local formatting = false
				vim.api.nvim_buf_attach(buf, false, {
					on_lines = function()
						if pending or formatting then
							return
						end
						pending = true
						-- debounce: tunggu sampai penulisan isi buffer selesai
						vim.defer_fn(function()
							pending = false
							formatting = true
							pcall(format_json_body, buf)
							formatting = false
						end, 80)
					end,
					on_detach = function()
						pcall(function()
							vim.b[buf].json_watcher = nil
						end)
					end,
				})
			end,
		})

		-- Ubah jendela hasil rest.nvim menjadi floating window (seperti :Mason)
		local function normal_win_count()
			local n = 0
			for _, w in ipairs(vim.api.nvim_list_wins()) do
				if vim.api.nvim_win_get_config(w).relative == "" then
					n = n + 1
				end
			end
			return n
		end

		local function float_result(win)
			if not vim.api.nvim_win_is_valid(win) then
				return
			end
			-- hanya sekali per window (mencegah loop BufWinEnter)
			if vim.w[win].rest_floated then
				return
			end
			if vim.api.nvim_win_get_config(win).relative ~= "" then
				vim.w[win].rest_floated = true
				return -- sudah floating
			end
			-- Neovim tidak boleh mengubah window terakhir menjadi float:
			-- biarkan tampil sebagai window biasa.
			if normal_win_count() <= 1 then
				return
			end
			vim.w[win].rest_floated = true
			local width = math.floor(vim.o.columns * 0.85)
			local height = math.floor(vim.o.lines * 0.8)
			local ok = pcall(vim.api.nvim_win_set_config, win, {
				relative = "editor",
				width = width,
				height = height,
				row = math.floor((vim.o.lines - height) / 2) - 1,
				col = math.floor((vim.o.columns - width) / 2),
				border = "rounded",
				title = " Response ",
				title_pos = "center",
				zindex = 50,
			})
			if ok and vim.api.nvim_win_is_valid(win) then
				vim.api.nvim_set_current_win(win)
			end
		end

		vim.api.nvim_create_autocmd("BufWinEnter", {
			group = group,
			callback = function(ev)
				if vim.bo[ev.buf].filetype ~= "rest_nvim_result" then
					return
				end
				vim.schedule(function()
					if not vim.api.nvim_buf_is_valid(ev.buf) then
						return
					end
					for _, win in ipairs(vim.fn.win_findbuf(ev.buf)) do
						float_result(win)
					end
				end)
			end,
		})

		-- Opsi tampilan: sembunyikan line number & gutter di buffer http / hasil
		vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" }, {
			group = group,
			pattern = { "rest_nvim_result", "http" },
			callback = function(args)
				local buf = args.buf
				local ft = vim.bo[buf].filetype

				if ft ~= "rest_nvim_result" and ft ~= "http" then
					return
				end

				vim.wo.number = false
				vim.wo.relativenumber = false
				vim.wo.signcolumn = "no"
				vim.wo.foldcolumn = "0"

				-- 'q' hanya di buffer hasil, memakai :close (bukan :q!) supaya
				-- tidak membuang perubahan file .http dan state window tetap bersih.
				if ft == "rest_nvim_result" then
					vim.keymap.set("n", "q", function()
						local win = vim.api.nvim_get_current_win()
						if normal_win_count() > 1 or vim.api.nvim_win_get_config(win).relative ~= "" then
							pcall(vim.api.nvim_win_close, win, true)
						else
							vim.cmd("quit")
						end
					end, {
						buffer = buf,
						silent = true,
						desc = "Close rest_nvim result window",
					})
				end
			end,
		})
	end,
	keys = {
		{ "<leader>R", "", desc = "Http Request" },
		{
			"<leader>Rr",
			function()
				pcall(function()
					vim.treesitter.get_parser(0, "http"):parse(true)
				end)
				vim.cmd("Rest run")
			end,
			desc = "Run HTTP request",
		},
		{ "<leader>Rl", "<cmd>Rest run last<cr>", desc = "Re-run last request" },
		{ "<leader>Re", "<cmd>Rest env select<cr>", desc = "Select .env file" },
	},
}
