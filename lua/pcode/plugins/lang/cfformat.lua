return {
	"pojokcodeid/auto-conform.nvim",
	opts = function(_, opts)
		opts.formatters = opts.formatters or {}
		opts.formatters_by_ft = opts.formatters_by_ft or {}

		opts.formatters.cfformat = {
			command = "sh",
			args = function(self, ctx)
				local workspace = vim.fs.root(ctx.buf, { ".vscode", ".git", ".cfformat.json" }) or vim.fn.getcwd()
				local file = ctx.filename
				local config_path = workspace .. "/soulbackend/client/danone/config/.cfformat.json"

				-- vim.notify("setting : " .. config_path, vim.log.levels.INFO)

				local cmd_str = string.format(
					"box cfformat run '%s' '%s' --overwrite && find '%s' -name '._*' -delete && find '%s' -name '.DS_Store' -delete",
					file,
					config_path,
					workspace,
					workspace
				)

				return { "-c", cmd_str }
			end,
			stdin = false,
		}

		opts.formatters_by_ft.cfml = { "cfformat" }
		opts.formatters_by_ft.cfc = { "cfformat" }
		opts.formatters_by_ft.cfm = { "cfformat" }

		return opts
	end,
}
