return {
	"pojokcodeid/auto-conform.nvim",
	dependencies = {
		"mason-org/mason.nvim",
		"stevearc/conform.nvim",
	},
	-- event = "VeryLazy",
	event = "BufRead",
	opts = function(_, opts)
		opts.formatters = opts.formatters or {}
		opts.formatters_by_ft = opts.formatters_by_ft or {}
		opts.ensure_installed = opts.ensure_installed or {}
		-- vim.list_extend(opts.ensure_installed, { "stylua" })
		opts.lang_maps = opts.lang_maps or {}
		opts.name_maps = opts.name_maps or {}
		opts.add_new = opts.add_new or {}
		opts.ignore = opts.ignore or {}
		opts.format_on_save = opts.format_on_save or true
		opts.format_timeout_ms = opts.format_timeout_ms or 5000
	end,
	config = function(_, opts)
		require("auto-conform").setup(opts)
		-- other conform config
		local conform = require("conform")
		if opts.format_on_save then
			conform.setup({
				format_on_save = function(bufnr)
					local notif_ok, notify = pcall(require, "notify")
					if notif_ok then
						local spinner = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
						local notif_id
						local i = 1
						local timer = vim.loop.new_timer()

						local function show_spinner(msg, duration)
							duration = duration or 3000 -- total durasi spinner berjalan (ms)

							timer:start(
								0,
								100,
								vim.schedule_wrap(function()
									notif_id = notify(spinner[i] .. " " .. msg, "info", {
										replace = notif_id,
										timeout = false, -- jangan auto-hilang selagi masih di-update
									})
									i = i % #spinner + 1
								end)
							)

							vim.defer_fn(function()
								if not timer:is_closing() then
									timer:stop()
									timer:close()
								end
								if notif_id then
									notify("✔ " .. msg .. " done", "info", {
										replace = notif_id,
										timeout = 1000, -- baru di sini kasih timeout normal
									})
								end
							end, duration)
						end

						show_spinner("Formatting ...", 1000)
					else
						print("Formatting ...")
					end

					return {
						lsp_fallback = true,
						timeout_ms = opts.format_timeout_ms or 5000,
					}
				end,
			})
		end
		vim.keymap.set({ "n", "v" }, "<leader>lF", function()
			conform.format({
				lsp_fallback = true,
				async = false,
				timeout_ms = opts.format_timeout_ms or 5000,
			})
		end, { desc = "Format file or range (in visual mode)" })
	end,
	keys = {
		{ "<leader>l", "", desc = "Lsp" },
	},
}
