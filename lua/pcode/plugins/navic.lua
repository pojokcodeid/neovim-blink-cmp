local M = {
	"SmiteshP/nvim-navic",
	event = "VeryLazy",
	dependencies = {
		"LunarVim/breadcrumbs.nvim",
		opts = {},
		config = true,
	},
}

function M.config()
	local icons = {
		Boolean = "󰨙",
		Color = "",
		Codeium = "󰘦",
		Control = "",
		Collapsed = " ",
		Component = "󰅴",
		Copilot = "",
		CopilotOff = "",
		Folder = "󰉋",
		Keyword = "",
		Reference = "",
		Snippet = "",
		TabNine = "󰏚",
		Text = "",
		Unit = "",
		Value = "",
		File = "",
		Module = "",
		Namespace = "",
		Package = "",
		Class = "",
		Method = "",
		Property = "",
		Field = "",
		Constructor = "",
		Enum = "",
		Interface = "",
		Function = "",
		Fragment = "󰅴",
		Variable = "",
		Constant = "",
		String = "",
		Number = "",
		Array = "",
		Object = "",
		Key = "",
		Null = "",
		EnumMember = "",
		Struct = "",
		Event = "",
		Operator = "",
		TypeParameter = "",
	}
	for key, value in pairs(icons) do
		icons[key] = value .. " "
	end
	require("nvim-navic").setup({
		icons = icons,
		lsp = {
			auto_attach = true,
			preference = nil,
		},
		highlight = false,
		separator = " > ",
		depth_limit = 0,
		depth_limit_indicator = "..",
		safe_output = true,
		lazy_update_context = false,
		click = false,
		format_text = function(text)
			return text
		end,
	})
end

return M
