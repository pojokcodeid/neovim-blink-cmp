-- Jalankan dot_clean -m pada current working directory
local function dot_clean()
	local cwd = vim.fn.getcwd()
	vim.fn.jobstart({ "dot_clean", "-m", cwd }, {
		detach = false,
		on_exit = function(_, code)
			if code ~= 0 then
				vim.schedule(function()
					vim.notify("dot_clean gagal (exit code " .. code .. ")", vim.log.levels.WARN)
				end)
			end
		end,
	})
end

local group = vim.api.nvim_create_augroup("DotClean", { clear = true })
-- Setiap kali file disimpan
vim.api.nvim_create_autocmd("BufWritePost", {
	group = group,
	callback = dot_clean,
})

-- Saat pindah buffer
vim.api.nvim_create_autocmd("BufHidden", {
	group = group,
	callback = dot_clean,
})

-- saat file dihapus
vim.api.nvim_create_autocmd("BufDelete", {
	group = group,
	callback = dot_clean,
})

-- Saat Neovim dibuka
vim.api.nvim_create_autocmd("VimEnter", { group = group, callback = dot_clean })

-- Saat Neovim ditutup (pakai jobwait agar selesai sebelum keluar)
vim.api.nvim_create_autocmd("VimLeavePre", {
	group = group,
	callback = function()
		local id = vim.fn.jobstart({ "dot_clean", "-m", vim.fn.getcwd() })
		vim.fn.jobwait({ id }, 3000)
	end,
})

-- Saat pindah direktori (:cd)
vim.api.nvim_create_autocmd("DirChanged", { group = group, callback = dot_clean })
