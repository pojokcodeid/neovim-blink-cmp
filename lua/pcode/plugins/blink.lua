return {
	"saghen/blink.cmp",
	event = { "InsertEnter", "CmdlineEnter" },
	dependencies = {
		"rafamadriz/friendly-snippets",
		{ "L3MON4D3/LuaSnip", version = "v2.*" },
	},
	version = "1.*",
	-- build = "cargo build --release",
	opts = function()
		return {
			snippets = { preset = "luasnip" },
			keymap = {
				preset = "none",
				["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
				["<Tab>"] = {
					function(cmp)
						if cmp.snippet_active() then
							return cmp.accept()
						else
							local has_words_before = function()
								local col = vim.api.nvim_win_get_cursor(0)[2]
								if col == 0 then
									return false
								end
								local line = vim.api.nvim_get_current_line()
								return line:sub(col, col):match("%s") == nil
							end

							return cmp.select_next({ auto_insert = has_words_before() })
						end
					end,
					"snippet_forward",
					"fallback",
				},
				["<S-Tab>"] = {
					function(cmp)
						if cmp.snippet_active() then
							return cmp.snippet_backward()
						else
							return cmp.select_prev()
						end
					end,
					"fallback",
				},
				["<CR>"] = { "accept", "fallback" },
				["<C-u>"] = {
					"scroll_documentation_up",
					"fallback",
				},
				["<C-d>"] = {
					"scroll_documentation_down",
					"fallback",
				},
				["<Up>"] = { "select_prev", "fallback" },
				["<Down>"] = { "select_next", "fallback" },
				["<C-p>"] = { "select_prev", "fallback_to_mappings" },
				["<C-n>"] = { "select_next", "fallback_to_mappings" },
				["<C-N>"] = { "select_next", "show" },
				["<C-P>"] = { "select_prev", "show" },
				["<C-J>"] = { "select_next", "fallback" },
				["<C-K>"] = { "select_prev", "fallback" },
				["<C-U>"] = { "scroll_documentation_up", "fallback" },
				["<C-D>"] = { "scroll_documentation_down", "fallback" },
				["<C-e>"] = { "hide", "fallback" },
			},
			appearance = {
				use_nvim_cmp_as_default = true,
				nerd_font_variant = "mono",
				kind_icons = {
					Array = "",
					Boolean = "󰨙",
					Class = "󰯳",
					Codeium = "󰘦",
					Color = "󰰠",
					Control = "",
					Collapsed = ">",
					Constant = "󰯲",
					Constructor = "",
					Copilot = "",
					Enum = "󰯹",
					EnumMember = "",
					Event = "",
					Field = "",
					File = "",
					Folder = "",
					Function = "󰯼",
					Interface = "󰰅",
					Key = "",
					Keyword = "",
					Method = "󰰑",
					Module = "󰰐",
					Namespace = "󰰔",
					Null = "",
					Number = "󰰔",
					Object = "󰲟",
					Operator = "",
					Package = "󰰚",
					Property = "󰲽",
					Reference = "󰰠",
					Snippet = "󰰢",
					String = "",
					Struct = "󰰣",
					TabNine = "󰏚",
					Text = "󰰥",
					TypeParameter = "󰰦",
					Unit = "󱜥",
					Value = "",
					Variable = "󰰬",
				},
			},
			completion = {
				accept = { auto_brackets = { enabled = true } },
				menu = {
					border = "rounded",
					winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:CursorLine,Search:None",
					draw = {
						padding = 2,
						gap = 1,
						treesitter = { "lsp" },
						columns = {
							{ "kind_icon" },
							{ "label", "label_description", gap = 1 },
							{ "kind" },
						},
					},
				},
				documentation = {
					auto_show = true,
					auto_show_delay_ms = 0,
					window = {
						border = "rounded",
						winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:CursorLine,Search:None",
					},
				},
				ghost_text = {
					enabled = true,
					hl_group = "Comment",
				},
			},
			signature = {
				enabled = true,
				window = { border = "rounded" },
			},
			cmdline = {
				keymap = { preset = "inherit" },
				completion = { menu = { auto_show = true } },
			},
			sources = {
				default = { "lsp", "path", "snippets", "buffer" },
				providers = {},
			},
			fuzzy = { implementation = "prefer_rust_with_warning" },
		}
	end,
	opts_extend = {
		"sources.default",
		"sources.providers",
	},
}
