return {
	"monkoose/neocodeium",
	-- event = "VeryLazy",
	event = "BufRead",
	dependencies = { "saghen/blink.cmp" },
	config = function()
		local uv = vim.uv
		local fn = vim.fn
		local pummenu_timer = assert(uv.new_timer())
		local neocodeium = require("neocodeium")
		local renderer = require("neocodeium.renderer")
		local completer = require("neocodeium.completer")
		local function is_noselect()
			local completeopt = vim.o.completeopt
			return completeopt:find("noselect") and -1 or 0
		end

		local default_selected_compl = is_noselect()
		local selected_compl = default_selected_compl
		local blink = require("blink.cmp")

		vim.api.nvim_create_autocmd("User", {
			pattern = "BlinkCmpMenu*",
			callback = function()
				neocodeium.clear()
			end,
		})

		neocodeium.setup({
			filter = function()
				return not blink.is_visible()
			end,
		})

		vim.api.nvim_create_autocmd("User", {
			pattern = "BlinkCmpMenuClose",
			callback = function()
				local cur_selected = fn.complete_info({ "selected" }).selected
				if selected_compl == cur_selected then
					completer:initiate()
				else
					selected_compl = cur_selected
					completer:clear(true)
					renderer:display_label()
					pummenu_timer:stop()
					pummenu_timer:start(
						400,
						0,
						vim.schedule_wrap(function()
							if fn.pumvisible() == 1 then
								completer:initiate()
							end
						end)
					)
				end
			end,
		})

		-- =========================
		-- Keymaps
		-- =========================
		vim.keymap.set("i", "<C-g>", neocodeium.accept, { desc = "Codeium Accept" })
		vim.keymap.set("i", "<C-x>", neocodeium.clear, { desc = "Codeium Clear" })
		vim.keymap.set("i", "<C-Up>", function()
			neocodeium.cycle(-1)
		end)
		vim.keymap.set("i", "<C-Down>", neocodeium.cycle)

		-- =========================
		-- Commands
		-- =========================
		vim.api.nvim_create_user_command("CodeiumDisable", function()
			require("neocodeium.commands").disable(true)
		end, {})

		vim.api.nvim_create_user_command("CodeiumEnable", function()
			require("neocodeium.commands").enable()
		end, {})
	end,
}
