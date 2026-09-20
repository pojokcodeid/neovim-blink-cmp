return {
	"windwp/nvim-autopairs",
	lazy = true,
	event = "InsertEnter",
	opts = {
		check_ts = true,
		ts_config = {
			lua = { "string", "source" },
			javascript = { "string", "template_string" },
			java = false,
		},
		disable_filetype = { "TelescopePrompt", "spectre_panel" },
		fast_wrap = {
			map = "<M-e>",
			chars = { "{", "[", "(", '"', "'", "`" },
			pattern = string.gsub([[ [%'%"%)%>%]%)%}%,] ]], "%s+", ""),
			offset = 0, -- Offset from pattern match
			end_key = "$",
			keys = "qwertyuiopzxcvbnmasdfghjkl",
			check_comma = true,
			highlight = "PmenuSel",
			highlight_grey = "LineNr",
		},
	},
	config = function(_, opts)
		local npairs = require("nvim-autopairs")
		npairs.setup(opts)

		local Rule = require("nvim-autopairs.rule")
		local cond = require("nvim-autopairs.conds")

		-- Aturan spasi otomatis di dalam kurung { | }
		npairs.add_rules({
			Rule(" ", " ")
				:with_pair(function(options)
					local pair = options.line:sub(options.col - 1, options.col)
					return vim.tbl_contains({ "{}", "()", "[]" }, pair)
				end)
				:with_move(cond.none())
				:with_cr(cond.none())
				:with_del(cond.none()),
		})
	end,
}
