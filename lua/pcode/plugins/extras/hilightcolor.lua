return {
	"saghen/blink.cmp",
	dependencies = {
		{
			"brenoprata10/nvim-highlight-colors",
			opts = {
				render = "background",
				---Set virtual symbol (requires render to be set to 'virtual')
				virtual_symbol = "■",
				---Set virtual symbol suffix (defaults to '')
				virtual_symbol_prefix = "",
				---Set virtual symbol suffix (defaults to ' ')
				virtual_symbol_suffix = " ",
				virtual_symbol_position = "inline",
				---Highlight hex colors, e.g. '#FFFFFF'
				enable_hex = true,
				---Highlight short hex colors e.g. '#fff'
				enable_short_hex = true,
				---Highlight rgb colors, e.g. 'rgb(0 0 0)'
				enable_rgb = true,
				---Highlight hsl colors, e.g. 'hsl(150deg 30% 40%)'
				enable_hsl = true,
				---Highlight ansi colors, e.g '\033[0;34m'
				enable_ansi = true,
				-- Highlight hsl colors without function, e.g. '--foreground: 0 69% 69%;'
				enable_hsl_without_function = true,
				---Highlight CSS variables, e.g. 'var(--testing-color)'
				enable_var_usage = true,
				---Highlight named colors, e.g. 'green'
				enable_named_colors = true,
				---Highlight tailwind colors, e.g. 'bg-blue-500'
				enable_tailwind = false,
			},
		},
	},
	opts = function(_, opts)
		opts.completion.menu.draw.components.kind_icon = {
			text = function(ctx)
				-- default kind icon
				local icon = ctx.kind_icon
				-- if LSP source, check for color derived from documentation
				if ctx.item.source_name == "LSP" then
					local color_item =
						require("nvim-highlight-colors").format(ctx.item.documentation, { kind = ctx.kind })
					if color_item and color_item.abbr ~= "" then
						icon = color_item.abbr
					end
				end
				return icon .. ctx.icon_gap
			end,
			highlight = function(ctx)
				-- default highlight group
				local highlight = "BlinkCmpKind" .. ctx.kind
				-- if LSP source, check for color derived from documentation
				if ctx.item.source_name == "LSP" then
					local color_item =
						require("nvim-highlight-colors").format(ctx.item.documentation, { kind = ctx.kind })
					if color_item and color_item.abbr_hl_group then
						highlight = color_item.abbr_hl_group
					end
				end
				return highlight
			end,
		}
	end,
}
