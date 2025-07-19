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
