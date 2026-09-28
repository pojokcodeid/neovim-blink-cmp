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
	end,
	keys = {
		{ "<leader>r", "", desc = "Http Request" },
		{ "<leader>rr", "<cmd>Rest run<cr>", desc = "Run HTTP request" },
		{ "<leader>rl", "<cmd>Rest run last<cr>", desc = "Re-run last request" },
		{ "<leader>re", "<cmd>Rest env select<cr>", desc = "Select .env file" },
	},
}
