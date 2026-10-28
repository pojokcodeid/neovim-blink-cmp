_G.LAZYGIT_TOGGLE = function()
	local ok = pcall(require, "toggleterm")
	if not ok then
		require("notify")("toggleterm not found!", "error")
		return
	end
	local Terminal = require("toggleterm.terminal").Terminal
	local lazygit = Terminal:new({ cmd = "lazygit", hidden = true })
	lazygit:toggle()
end

local lazydocker_term = nil

_G.LAZYDOCKER_TOGGLE = function()
	local ok, terminal = pcall(require, "toggleterm.terminal")
	if not ok then
		vim.notify("toggleterm not found!", vim.log.levels.ERROR)
		return
	end

	if not lazydocker_term then
		-- Ambil path socket Podman machine
		local out = vim.fn.systemlist("podman machine inspect --format '{{.ConnectionInfo.PodmanSocket.Path}}'")
		if vim.v.shell_error ~= 0 or not out[1] or out[1] == "" then
			vim.notify("Podman machine tidak jalan / socket tidak ditemukan", vim.log.levels.ERROR)
			return
		end

		lazydocker_term = terminal.Terminal:new({
			cmd = "lazydocker",
			hidden = true,
			direction = "float",
			env = { DOCKER_HOST = "unix://" .. out[1] },
			on_exit = function()
				lazydocker_term = nil -- buat ulang saat dibuka lagi (path socket bisa berubah)
			end,
		})
	end

	lazydocker_term:toggle()
end

local function safeRequire(module)
	local ok, result = pcall(require, module)
	if ok then
		return result
	end
end

safeRequire("pcode.user.options")
safeRequire("pcode.user.autocmd")
safeRequire("pcode.user.keymaps")
return {}
