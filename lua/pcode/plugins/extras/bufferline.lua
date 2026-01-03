return {
	"willothy/nvim-cokeline",
	event = { "BufRead", "BufNewFile" },
	opts = function()
		local truncate_text = function(text, max_length)
			if #text > max_length then
				local first_text = text:sub(1, 5)
				local end_text = text:sub(#text - 7, #text)
				return first_text .. "..." .. end_text
			else
				return text
			end
		end

		local yellow = vim.g.terminal_color_3
		local hlgroups = require("cokeline.hlgroups")
		local hl_attr = hlgroups.get_hl_attr
		return {
			sidebar = {
				filetype = { "NvimTree", "neo-tree" },
				components = {
					{
						text = " ",
						bg = hl_attr("Normal", "bg"),
					},
					{
						text = function(buf)
							if buf.filetype == "neo-tree" then
								return "Explorer"
							else
								return vim.fn.fnamemodify(vim.fn.getcwd(), ":t") or "Explorer"
							end
						end,
						fg = yellow,
						bg = function()
							return hl_attr("Normal", "bg")
						end,
						bold = true,
					},
				},
			},
			components = {
				{
					text = " ",
					bg = hl_attr("Normal", "bg"),
				},
				{
					text = "",
					fg = function(buffer)
						if buffer.is_focused then
							return hl_attr("ColorColumnTab", "bg")
						else
							return hl_attr("NormalTab", "bg")
						end
					end,
					bg = hl_attr("Normal", "bg"),
				},
				{
					text = function(buffer)
						return buffer.devicon.icon
					end,
					fg = function(buffer)
						return buffer.devicon.color
					end,
					bg = function(buffer)
						return buffer.is_focused and hl_attr("ColorColumnTab", "bg") or hl_attr("NormalTab", "bg")
					end,
				},
				{
					text = " ",
					bg = function(buffer)
						return buffer.is_focused and hl_attr("ColorColumnTab", "bg") or hl_attr("NormalTab", "bg")
					end,
				},
				{
					text = function(buffer)
						return truncate_text(buffer.filename, 15) .. " "
					end,
					style = function(buffer)
						return buffer.is_focused and "bold" or nil
					end,
					bg = function(buffer)
						return buffer.is_focused and hl_attr("ColorColumnTab", "bg") or hl_attr("NormalTab", "bg")
					end,
				},
				{
					text = "󰅖",
					delete_buffer_on_left_click = true,
					bg = function(buffer)
						return buffer.is_focused and hl_attr("ColorColumnTab", "bg") or hl_attr("NormalTab", "bg")
					end,
				},
				{
					text = "",
					fg = function(buffer)
						if buffer.is_focused then
							return hl_attr("ColorColumnTab", "bg")
						else
							return hl_attr("NormalTab", "bg")
						end
					end,
					bg = hl_attr("Normal", "bg"),
				},
			},
		}
	end,
	keys = {
		{ "<leader>b", "", desc = "Buffers", mode = "n" },
		{
			"<Leader>bp",
			"<Plug>(cokeline-switch-prev)",
			desc = "Focus Previous buffer",
			mode = "n",
		},
		{
			"<Leader>bn",
			"<Plug>(cokeline-switch-next)",
			desc = "Focus next buffer",
			mode = "n",
		},
		{
			"<leader>bb",
			function()
				require("telescope.builtin").buffers(require("telescope.themes").get_dropdown({ previewer = false }))
			end,
			desc = "All Buffer",
			mode = "n",
		},
		{
			"<leader>bc",
			function()
				require("pcode.user.buffer").bufremove()
			end,
			desc = "Close current buffer",
			mode = "n",
		},
		{
			"<S-Tab>",
			"<Plug>(cokeline-focus-prev)",
			desc = "Focus previous buffer",
			mode = "n",
		},
		{
			"<Tab>",
			"<Plug>(cokeline-focus-next)",
			desc = "Focus buffer Next",
			mode = "n",
		},
		{
			"<S-PageUp>",
			"<Plug>(cokeline-switch-prev)",
			desc = "Switch to previous buffer",
			mode = "n",
		},
		{
			"<S-PageDown>",
			"<Plug>(cokeline-switch-next)",
			desc = "Switch to next buffer",
			mode = "n",
		},
		{
			"<S-t>",
			function()
				require("pcode.user.buffer").bufremove()
			end,
			desc = "Close Current Buffer",
			mode = "n",
		},
	},
}
