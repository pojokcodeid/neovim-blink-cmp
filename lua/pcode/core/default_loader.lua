local M = {}

function M.load()
	-- local ok, cfg = pcall(dofile, vim.fn.stdpath("config") .. "/lua/pcode/user/default.lua")
	local paths = {
		vim.fn.stdpath("config") .. "/lua/pcode/user/default.lua",
		vim.fn.stdpath("config") .. "/lua/user/default.lua",
	}

	local ok, cfg
	for _, path in ipairs(paths) do
		ok, cfg = pcall(dofile, path)
		if ok then
			break
		end
	end

	if not ok then
		vim.notify("Gagal load default.lua", vim.log.levels.ERROR)
		return nil
	end

	return cfg or _G.pcode
end

return M
