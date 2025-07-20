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
