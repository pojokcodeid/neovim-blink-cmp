return {
	"saghen/blink.cmp",
	event = { "InsertEnter", "CmdlineEnter" },
	dependencies = {
		"rafamadriz/friendly-snippets",
		"mikavilpas/blink-ripgrep.nvim",
		"xzbdmw/colorful-menu.nvim",
		{ "L3MON4D3/LuaSnip", version = "v2.*" },
		{
			"Exafunction/codeium.nvim",
			cmd = "Codeium",
			build = ":Codeium Auth",
			opts = {
				enable_chat = true,
				enable_cmp_source = true,
				virtual_text = {
					enabled = false,
					key_bindings = {
						accept = "<c-g>",
						next = "<c-Down>",
						prev = "<c-Up>",
					},
				},
			},
			config = function(_, opts)
				require("codeium").setup(opts)
			end,
		},
	},
	version = "1.*",
	build = "cargo build --release",
	opts = {
		snippets = { preset = "luasnip" },
		keymap = {
			preset = "none",
			["<C-space>"] = { "show" },
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
				--[[ 	draw = {
					columns = { { "kind_icon" }, { "label", gap = 0 } },
					components = {
						label = {
							text = require("colorful-menu").blink_components_text,
							highlight = require("colorful-menu").blink_components_highlight,
						},
					},
				}, ]]
				draw = {
					padding = 2,
					gap = 1,
					treesitter = { "lsp" },
					columns = {
						{ "kind_icon" },
						{ "label", "label_description", gap = 1 },
						{ "kind" },
					},
					components = {
						label = {
							text = require("colorful-menu").blink_components_text,
							highlight = require("colorful-menu").blink_components_highlight,
						},
					},
				},
			},
			documentation = {
				auto_show = true,
				auto_show_delay_ms = 0,
				window = {
					border = "rounded",
				},
			},
			ghost_text = {
				enabled = true,
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
			default = { "lsp", "path", "snippets", "buffer", "ripgrep", "codeium" },
			providers = {
				ripgrep = {
					module = "blink-ripgrep",
					name = "Ripgrep",
					opts = {
						prefix_min_len = 3,
						backend = {
							context_size = 5,
							ripgrep = {
								max_filesize = "1M",
								additional_rg_options = {},
							},
						},
					},
					transform_items = function(_, items)
						for _, item in ipairs(items) do
							item.kind_name = "Ripgrep"
						end
						return items
					end,
				},
				codeium = { name = "Codeium", module = "codeium.blink", async = true },
			},
		},
		fuzzy = { implementation = "prefer_rust_with_warning" },
	},
	opts_extend = {
		"sources.default",
		"sources.providers",
	},
}
