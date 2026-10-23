return {
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "main",
		event = "VeryLazy",
		-- lazy = false, -- branch main tidak mendukung lazy-loading
		build = ":TSUpdate",
		config = function()
			-- daftarkan parser custom CFML SEBELUM :TSUpdate dipanggil
			vim.api.nvim_create_autocmd("User", {
				pattern = "TSUpdate",
				callback = function()
					local parsers = require("nvim-treesitter.parsers")

					parsers.cfml = {
						install_info = {
							url = "https://github.com/cfmleditor/tree-sitter-cfml",
							location = "cfml",
							files = { "src/parser.c", "src/scanner.c" },
							branch = "master",
						},
					}

					parsers.cfscript = {
						install_info = {
							url = "https://github.com/cfmleditor/tree-sitter-cfml",
							location = "cfscript",
							files = { "src/parser.c", "src/scanner.c" },
							branch = "master",
						},
					}

					parsers.dotenv = {
						install_info = {
							url = "https://github.com/pnx/tree-sitter-dotenv",
						},
						filetype = "dotenv",
					}
				end,
			})

			local ts = require("nvim-treesitter")
			ts.setup({})

			-- petakan filetype -> parser
			vim.treesitter.language.register("javascript", "javascriptreact")
			vim.treesitter.language.register("tsx", "typescriptreact")

			-- nyalakan treesitter untuk satu buffer, jika parser-nya sudah terinstal
			local no_ts_indent = { cfml = true, cfscript = true }

			local function attach(buf)
				if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) then
					return
				end
				local ft = vim.bo[buf].filetype
				if ft == "" then
					return
				end

				local lang = vim.treesitter.language.get_lang(ft) or ft
				-- parser belum terinstal -> lewati tanpa error
				if not pcall(vim.treesitter.language.add, lang) then
					return
				end
				-- highlight
				if not pcall(vim.treesitter.start, buf, lang) then
					return
				end

				vim.api.nvim_buf_call(buf, function()
					-- fold
					vim.wo[0][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
					vim.wo[0][0].foldmethod = "expr"

					-- indent
					if no_ts_indent[lang] then
						vim.bo.autoindent = true
						vim.bo.indentexpr = ""
					elseif vim.treesitter.query.get(lang, "indents") then
						vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
					end
				end)
			end

			local function attach_all()
				for _, buf in ipairs(vim.api.nvim_list_bufs()) do
					attach(buf)
				end
			end

			-- setiap kali filetype di-set, coba nyalakan (tanpa pattern = semua filetype)
			vim.api.nvim_create_autocmd("FileType", {
				group = vim.api.nvim_create_augroup("UserTreesitterAttach", { clear = true }),
				callback = function(args)
					attach(args.buf)
				end,
			})

			-- buffer yang sudah terbuka sebelum config ini jalan
			attach_all()

			-- install parser; setelah selesai, nyalakan di buffer yang sudah terbuka
			ts.install({
				"lua",
				"luadoc",
				"printf",
				"vim",
				"vimdoc",
				"javascript",
				"typescript",
				"tsx",
				"html",
				"json",
				"cfml",
				"cfscript",
				"sql",
			}):await(function()
				vim.schedule(attach_all)
			end)

			vim.api.nvim_create_user_command("TSInstallInfo", function()
				local pickers = require("telescope.pickers")
				local finders = require("telescope.finders")
				local conf = require("telescope.config").values
				local actions = require("telescope.actions")
				local action_state = require("telescope.actions.state")

				local function build_results()
					local installed = {}
					for _, lang in ipairs(ts.get_installed()) do
						installed[lang] = true
					end

					local results = {}
					for _, lang in ipairs(ts.get_available()) do
						table.insert(results, { lang = lang, installed = installed[lang] or false })
					end

					-- yang sudah ter-install tampil di atas
					table.sort(results, function(a, b)
						if a.installed ~= b.installed then
							return a.installed
						end
						return a.lang < b.lang
					end)
					return results
				end

				local function make_finder()
					return finders.new_table({
						results = build_results(),
						entry_maker = function(e)
							return {
								value = e,
								ordinal = e.lang,
								display = (e.installed and "✓ " or "  ") .. e.lang,
							}
						end,
					})
				end

				pickers
					.new({}, {
						prompt_title = "Treesitter Parsers (Enter: install / uninstall)",
						finder = make_finder(),
						sorter = conf.generic_sorter({}),
						attach_mappings = function(bufnr)
							actions.select_default:replace(function()
								local sel = action_state.get_selected_entry()
								if not sel then
									return
								end
								local lang = sel.value.lang

								actions.close(bufnr)

								local is_installed = vim.list_contains(ts.get_installed(), lang)

								if is_installed then
									vim.notify("Uninstalling parser: " .. lang, vim.log.levels.INFO)
									ts.uninstall({ lang }):await(function()
										vim.notify("Parser uninstalled: " .. lang, vim.log.levels.INFO)
									end)
								else
									vim.notify("Installing parser: " .. lang, vim.log.levels.INFO)
									ts.install({ lang }):await(function()
										vim.notify("Parser installed: " .. lang, vim.log.levels.INFO)
										-- langsung nyalakan di buffer yang sedang terbuka
										vim.schedule(attach_all)
									end)
								end
							end)
							return true
						end,
					})
					:find()
			end, {})
		end,
	},
	-- filetype detection CFML
	{
		"nvim-lua/plenary.nvim",
		-- lazy = false,
		event = "VeryLazy",
		priority = 1000, -- supaya filetype terdaftar sebelum file dibuka
		config = function()
			vim.filetype.add({
				extension = {
					cfm = "cfml",
					cfml = "cfml",
					cfc = "cfml",
					sfc = "cfml",
					cfs = "cfscript",
					jsx = "javascriptreact",
				},
				filename = {
					[".env"] = "dotenv",
				},
				pattern = {
					["%.env%..+"] = "dotenv",
				},
			})
		end,
	},
}
