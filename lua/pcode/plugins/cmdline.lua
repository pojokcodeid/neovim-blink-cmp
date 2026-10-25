return {
	{
		"rcarriga/nvim-notify",
		lazy = true,
		keys = {
			{ "<leader>u", "", desc = "Notify" },
			{
				"<leader>uN",
				function()
					require("notify").dismiss({ silent = true, pending = true })
				end,
				desc = "Delete all Notifications",
			},
		},
		opts = {
			timeout = 3000,
			max_height = function()
				return math.floor(vim.o.lines * 0.75)
			end,
			max_width = function()
				return math.floor(vim.o.columns * 0.4)
			end,
			render = "wrapped-compact",
		},
		config = function(_, opts)
			local notify = require("notify")
			notify.setup(opts)
			vim.notify = notify.notify
		end,
	},

	{
		"folke/noice.nvim",
		enabled = true,
		event = "VeryLazy",
		dependencies = {
			"MunifTanjim/nui.nvim",
			"rcarriga/nvim-notify",
		},
		opts = {
			messages = { enabled = false },
			notify = { enabled = false }, -- vim.notify sudah dihandle nvim-notify
			lsp = {
				progress = { enabled = false },
				hover = { enabled = false },
				signature = { enabled = false },
			},
			routes = {
				-- sembunyikan pesan yang tidak penting
				{
					filter = {
						event = "msg_show",
						kind = "",
						any = {
							{ find = "%d+L, %d+B" },
							{ find = "; after #%d+" },
							{ find = "; before #%d+" },
							{ find = "search hit" },
						},
					},
					opts = { skip = true },
				},
				-- Pattern not found (E486) -> nvim-notify
				{
					filter = {
						event = "msg_show",
						any = {
							{ find = "E486" },
							{ find = "Pattern not found" },
						},
					},
					view = "notify",
					opts = { level = "warn", title = "Search" },
				},
				-- semua error lain -> nvim-notify
				{
					filter = { event = "msg_show", kind = "emsg" },
					view = "notify",
				},
			},
			presets = {
				command_bar_cursor = {
					enabled = true,
					cursor_shape = "ver30",
				},
			},
		},
		keys = {
			{
				"<S-Enter>",
				function()
					require("noice").redirect(vim.fn.getcmdline())
				end,
				mode = "c",
				desc = "Redirect Cmdline",
			},
			{
				"<leader>snl",
				function()
					require("noice").cmd("last")
				end,
				desc = "Noice Last Message",
			},
			{
				"<leader>snh",
				function()
					require("noice").cmd("history")
				end,
				desc = "Noice History",
			},
			{
				"<leader>sna",
				function()
					require("noice").cmd("all")
				end,
				desc = "Noice All",
			},
			{
				"<c-f>",
				function()
					if not require("noice.lsp").scroll(4) then
						return "<c-f>"
					end
				end,
				silent = true,
				expr = true,
				desc = "Scroll forward",
				mode = { "i", "n", "s" },
			},
			{
				"<c-b>",
				function()
					if not require("noice.lsp").scroll(-4) then
						return "<c-b>"
					end
				end,
				silent = true,
				expr = true,
				desc = "Scroll backward",
				mode = { "i", "n", "s" },
			},
		},
	},
}
