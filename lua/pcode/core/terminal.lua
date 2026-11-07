-- ============================================================================
-- Terminal Helpers (Lazygit & Lazydocker)
-- ============================================================================
local M = {}

--- Toggle Lazygit floating terminal
_G.LAZYGIT_TOGGLE = function()
	local ok = pcall(require, "toggleterm")
	if not ok then
		vim.notify("toggleterm not found!", vim.log.levels.ERROR)
		return
	end
	local Terminal = require("toggleterm.terminal").Terminal
	local lazygit = Terminal:new({ cmd = "lazygit", hidden = true })
	lazygit:toggle()
end

local lazydocker_term = nil

--- Toggle Lazydocker floating terminal (dengan support socket Podman)
_G.LAZYDOCKER_TOGGLE = function()
	local ok, terminal = pcall(require, "toggleterm.terminal")
	if not ok then
		vim.notify("toggleterm not found!", vim.log.levels.ERROR)
		return
	end

	if not lazydocker_term then
		-- Ambil path socket Podman machine jika ada
		local out = vim.fn.systemlist("podman machine inspect --format '{{.ConnectionInfo.PodmanSocket.Path}}'")
		local env = nil
		if vim.v.shell_error == 0 and out[1] and out[1] ~= "" then
			env = { DOCKER_HOST = "unix://" .. out[1] }
		end

		lazydocker_term = terminal.Terminal:new({
			cmd = "lazydocker",
			hidden = true,
			direction = "float",
			env = env,
			on_exit = function()
				lazydocker_term = nil -- buat ulang saat dibuka lagi jika path socket berubah
			end,
		})
	end

	lazydocker_term:toggle()
end

M.lazygit_toggle = _G.LAZYGIT_TOGGLE
M.lazydocker_toggle = _G.LAZYDOCKER_TOGGLE

return M
