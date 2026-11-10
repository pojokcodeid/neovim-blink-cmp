local M = {}

function M.save_tokens(response)
	local ok, body = pcall(vim.json.decode, response.body)

	if not ok then
		-- isi dengan nilai > 0 akan watu timer ms untuk close
		-- isi dengan 0 tidak auto close
		-- tidak diisi default 3 detik close
		require("pcode.user.notifyshow").show(
			"Response bukan JSON valid" .. vim.inspect(body),
			vim.log.levels.ERROR,
			200
		)
		return
	end

	local data = body.DATA

	if not data then
		require("pcode.user.notifyshow").show("DATA tidak ditemukan:\n" .. vim.inspect(body), vim.log.levels.ERROR)
		return
	end

	if not data.ACCESS_TOKEN or not data.REFRESH_TOKEN then
		require("pcode.user.notifyshow").show("Token tidak ditemukan:\n" .. vim.inspect(data), vim.log.levels.ERROR, 0)
		return
	end

	vim.g.accessToken = data.ACCESS_TOKEN
	vim.g.refreshToken = data.REFRESH_TOKEN

	vim.notify("Token berhasil disimpan", vim.log.levels.INFO)
end

return M
