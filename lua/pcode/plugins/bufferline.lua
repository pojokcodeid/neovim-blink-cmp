return {
	"willothy/nvim-cokeline",
	event = { "BufRead", "BufNewFile" },
	opts = function()
		local yellow = vim.g.terminal_color_3
		local hlgroups = require("cokeline.hlgroups")
		local hl_attr = hlgroups.get_hl_attr
		return {
			sidebar = {
				filetype = { "NvimTree", "neo-tree" },
				components = {
					{
						text = function(buf)
							return buf.filetype
						end,
						fg = yellow,
						bg = function()
							return hl_attr("NvimTreeNormal", "bg")
						end,
						bold = true,
					},
				},
			},
			default_hl = {
				fg = function(buffer)
					return buffer.is_focused and hl_attr("Normal", "fg") or hl_attr("Comment", "fg")
				end,
				bg = function(buffer)
					return buffer.is_focused and hl_attr("ColorColumn", "bg") or hl_attr("Normal", "bg")
				end,
			},
			components = {
				{
					text = function(buffer)
						if buffer.is_focused then
							return "▎" .. buffer.devicon.icon
						else
							return "｜" .. buffer.devicon.icon
						end
					end,
					fg = function(buffer)
						return buffer.devicon.color
					end,
				},
				{
					text = " ",
				},
				{
					text = function(buffer)
						return buffer.filename .. " "
					end,
					style = function(buffer)
						return buffer.is_focused and "bold" or nil
					end,
					italic = function(buffer)
						return buffer.is_focused and true or nil
					end,
				},
				{
					text = "󰅖 ",
					delete_buffer_on_left_click = true,
				},
			},
		}
	end,
	keys = {
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
			"<Leader>p",
			"<Plug>(cokeline-switch-prev)",
			desc = "Focus Previous buffer",
			mode = "n",
		},
		{
			"<Leader>n",
			"<Plug>(cokeline-switch-next)",
			desc = "Focus next buffer",
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
