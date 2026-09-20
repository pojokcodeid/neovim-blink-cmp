return {
	{ "nvim-lua/plenary.nvim", event = "VeryLazy" },
	{
		"nvim-treesitter/nvim-treesitter",
		event = { "BufRead", "BufNewFile" },
		version = false,
		branch = "master", -- sementara sampai stabil
		build = ":TSUpdate",
		lazy = true,
		cmd = {
			"TSInstall",
			"TSInstallSync",
			"TSUpdate",
			"TSUpdateSync",
			"TSUninstall",
			"TSUninstallInfo",
			"TSInstallFromGrammar",
		},
		opts = function()
			return {
				highlight = { enable = true },
				indent = { enable = true, disable = { "cfml", "cfscript", "cfc", "cfm" } },
				ensure_installed = { "lua", "luadoc", "printf", "vim", "vimdoc" },
				incremental_selection = {
					enable = true,
				},
				autopairs = {
					enable = true,
				},
			}
		end,
		config = function(_, opts)
			-- daftarkan parser custom CFML SEBELUM .setup() dipanggil
			local parser_config = require("nvim-treesitter.parsers").get_parser_configs()

			parser_config.cfml = {
				install_info = {
					url = "https://github.com/cfmleditor/tree-sitter-cfml",
					location = "cfml",
					files = { "src/parser.c", "src/scanner.c" },
					branch = "master",
				},
				requires_generate_from_grammar = false,
				filetype = "cfml",
			}

			parser_config.cfscript = {
				install_info = {
					url = "https://github.com/cfmleditor/tree-sitter-cfml",
					location = "cfscript",
					files = { "src/parser.c", "src/scanner.c" },
					branch = "master",
				},
				requires_generate_from_grammar = false,
				filetype = "cfscript",
			}
			if type(opts.ensure_installed) == "table" then
				---@type table<string, boolean>
				local added = {}
				opts.ensure_installed = vim.tbl_filter(function(lang)
					if added[lang] then
						return false
					end
					added[lang] = true
					return true
				end, opts.ensure_installed)
			end
			require("nvim-treesitter.configs").setup(opts)
			vim.api.nvim_create_user_command("TSInstallInfo", function()
				vim.cmd("Telescope treesitter_info")
			end, {})
		end,
	},
	-- filetype detection CFML — plugin terpisah, dieksekusi paling awal
	{
		"nvim-lua/plenary.nvim",
		lazy = false,
		priority = 1000,
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
