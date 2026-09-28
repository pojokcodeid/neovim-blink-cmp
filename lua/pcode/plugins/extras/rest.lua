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
					format = true, -- auto-format body (JSON via jq, dll.)
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
		end

		vim.api.nvim_create_autocmd("FileType", {
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
		local function float_result(win)
			if not vim.api.nvim_win_is_valid(win) then
				return
			end
			if vim.api.nvim_win_get_config(win).relative ~= "" then
				return -- sudah floating
			end
			local width = math.floor(vim.o.columns * 0.85)
			local height = math.floor(vim.o.lines * 0.8)
			vim.api.nvim_win_set_config(win, {
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
			vim.api.nvim_set_current_win(win)
		end

		vim.api.nvim_create_autocmd("BufWinEnter", {
			callback = function(ev)
				if vim.bo[ev.buf].filetype ~= "rest_nvim_result" then
					return
				end
				vim.schedule(function()
					for _, win in ipairs(vim.fn.win_findbuf(ev.buf)) do
						float_result(win)
					end
				end)
			end,
		})
	end,
	keys = {
		{ "<leader>r", "", desc = "Http Request" },
		{ "<leader>rr", "<cmd>Rest run<cr>", desc = "Run HTTP request" },
		{ "<leader>rl", "<cmd>Rest run last<cr>", desc = "Re-run last request" },
		{ "<leader>re", "<cmd>Rest env select<cr>", desc = "Select .env file" },
	},
}
