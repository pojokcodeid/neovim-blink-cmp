return {
	"pojokcodeid/npm-runner.nvim",
	event = "VeryLazy",
	dependencies = {
		"rcarriga/nvim-notify",
	},
	-- your opts go here
	opts = {
		command = {
			dev = {
				start = "NpmRunDev",
				stop = "NpmStopDev",
				cmd = "npm run dev",
			},
			prod = {
				start = "NpmStart",
				stop = "NpmStop",
				cmd = "npm start",
			},
		},
		opt = {
			show_mapping = "<leader>nm",
			hide_mapping = "<leader>nh",
			width = 70,
			height = 20,
		},
	},
	keys = {
		{ "<leader>n", "", desc = "  Npm" },
	},
	config = function(_, opts)
		require("npm-runner").setup(opts.command, opts.opt)
	end,
}
