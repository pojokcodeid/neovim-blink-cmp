return {
	{
		"kristijanhusak/vim-dadbod-ui",
		dependencies = {
			{ "tpope/vim-dadbod", lazy = true },
			{ "kristijanhusak/vim-dadbod-completion", ft = { "sql", "mysql", "plsql" }, lazy = true },
		},
		cmd = {
			"DBUIToggle",
			"DBUI",
			"DBUIAddConnection",
			"DBUIFindBuffer",
			"DBUIRenameBuffer",
			"DBUILastQueryInfo",
		},
		init = function()
			-- Your DBUI configuration
			vim.g.db_ui_show_database_icon = 1
			vim.g.db_ui_use_nerd_fonts = 1
			vim.g.db_ui_show_help = 0
		end,
		keys = {
			{ "<leader>D", "", desc = " 󰆼 DBUI" },
			{ "<leader>Dd", "<cmd>Alpha<cr><cmd>NvimTreeClose<cr><cmd>DBUI<cr>", desc = "󰆼 DBUI Open" },
			{
				"<leader>Dq",
				"<cmd>DBUIClose<cr><cmd>BufferLineCloseOthers<cr><cmd>bd!<cr><cmd>lua require('auto-bufferline.configs.utils').bufremove()<cr><cmd>Alpha<cr>",
				desc = "󰅙 DBUI Close",
			},
		},
	},
	{ -- optional saghen/blink.cmp completion source
		"saghen/blink.cmp",
		opts = function(_, opts)
			opts.sources.per_filetype = {
				sql = { "snippets", "dadbod", "buffer" },
			}
			opts.sources.providers.dadbod = {
				name = "Dadbod",
				module = "vim_dadbod_completion.blink",
			}
		end,
	},
}
