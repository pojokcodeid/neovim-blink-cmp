local M = {}

function M.load()
	local ok, cfg = pcall(dofile, vim.fn.stdpath("config") .. "/lua/pcode/user/default.lua")

	if not ok then
		vim.notify("Gagal load default.lua", vim.log.levels.ERROR)
		return nil
	end

	return cfg or _G.pcode
end

return M
