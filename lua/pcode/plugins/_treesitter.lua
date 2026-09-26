return {
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "main",
		event = "BufRead",
		lazy = false, -- branch main TIDAK mendukung lazy-loading
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
				end,
			})

			require("nvim-treesitter").setup({})

			-- install parser yang dibutuhkan
			require("nvim-treesitter").install({
				"lua",
				"luadoc",
				"printf",
				"vim",
				"vimdoc",
				"javascript",
				"typescript",
				"tsx",
				"html",
				"cfml",
				"cfscript",
				"sql",
			})

			local ts_filetypes = {
				"lua",
				"vim",
				"vimdoc",
				"javascript",
				"typescript",
				"typescriptreact",
				"javascriptreact",
				"html",
				"cfml",
				"cfscript",
				"sql",
			}

			-- filetype yang PUNYA query indent lengkap (bukan cfml/cfscript)
			local ts_indent_filetypes = {
				"lua",
				"vim",
				"vimdoc",
				"javascript",
				"typescript",
				"typescriptreact",
				"javascriptreact",
				"html",
				"sql",
			}

			-- highlight
			vim.api.nvim_create_autocmd("FileType", {
				pattern = ts_filetypes,
				callback = function()
					pcall(vim.treesitter.start)
				end,
			})

			-- indent
			vim.api.nvim_create_autocmd("FileType", {
				pattern = ts_indent_filetypes,
				callback = function()
					vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
				end,
			})

			-- untuk cfml/cfscript, pastikan pakai autoindent bawaan Vim
			vim.api.nvim_create_autocmd("FileType", {
				pattern = { "cfml", "cfscript" },
				callback = function()
					vim.bo.autoindent = true
					vim.bo.indentexpr = "" -- kosongkan, biar fallback ke autoindent biasa
				end,
			})

			-- fold
			vim.api.nvim_create_autocmd("FileType", {
				pattern = ts_filetypes,
				callback = function()
					vim.wo[0][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
					vim.wo[0][0].foldmethod = "expr"
				end,
			})

			vim.api.nvim_create_user_command("TSInstallInfo", function()
				vim.cmd("Telescope treesitter_info")
			end, {})
		end,
	},
	-- filetype detection CFML
	{
		"nvim-lua/plenary.nvim",
		-- lazy = false,
		-- priority = 1000,
		event = "VeryLazy",
		config = function()
			vim.filetype.add({
				extension = {
					cfm = "cfml",
					cfml = "cfml",
					cfc = "cfml",
					sfc = "cfml",
					cfs = "cfscript",
				},
			})
		end,
	},
}
