local M = {}

-- daftar server tetap, tambahkan manual kalau nanti ada server lain
local servers = { "sf7-dev" }

local actions = {
	{ label = "Start", cmd = "start" },
	{ label = "Restart", cmd = "restart" },
	{ label = "Stop", cmd = "stop" },
}

local jobs = {} -- job_id per server, untuk tracking

local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.INFO, { title = "BoxRun" })
end

local function open_browser(url)
	vim.fn.jobstart({ "open", url }, { detach = true })
end

local function run_box(server, action_cmd)
	local cmd = { "box", "server", action_cmd, "name=" .. server }

	notify(("Menjalankan: box server %s name=%s"):format(action_cmd, server))

	local job_id = vim.fn.jobstart(cmd, {
		stdout_buffered = false,
		on_stdout = function(_, data)
			if not data then
				return
			end
			for _, line in ipairs(data) do
				if line ~= "" then
					local url = line:match("(https?://[%w%.:%-/]+)")
					if url and action_cmd == "start" then
						open_browser(url)
						notify("Server " .. server .. " running di " .. url)
					end
				end
			end
		end,
		on_stderr = function(_, data)
			if not data then
				return
			end
			for _, line in ipairs(data) do
				if line ~= "" then
					notify(line, vim.log.levels.WARN)
				end
			end
		end,
		on_exit = function(_, code)
			jobs[server] = nil
			if code == 0 then
				notify(("box server %s (%s) selesai"):format(action_cmd, server))
			else
				notify(
					("box server %s (%s) gagal, exit code %d"):format(action_cmd, server, code),
					vim.log.levels.ERROR
				)
			end
		end,
	})

	jobs[server] = job_id
end

local function pick_server(callback)
	if #servers == 1 then
		callback(servers[1])
		return
	end
	vim.ui.select(servers, { prompt = "Pilih server:" }, function(choice)
		if choice then
			callback(choice)
		end
	end)
end

function M.box_run()
	local labels = {}
	for _, a in ipairs(actions) do
		table.insert(labels, a.label)
	end

	vim.ui.select(labels, { prompt = "BoxRun - pilih aksi:" }, function(choice)
		if not choice then
			return
		end

		local action
		for _, a in ipairs(actions) do
			if a.label == choice then
				action = a
				break
			end
		end
		if not action then
			return
		end

		pick_server(function(server)
			run_box(server, action.cmd)
		end)
	end)
end

function M.box_status()
	pick_server(function(server)
		notify("Mengecek status " .. server .. "...")
		vim.fn.jobstart({ "box", "server", "status", "name=" .. server }, {
			stdout_buffered = true,
			on_stdout = function(_, data)
				if not data then
					return
				end
				local text = table.concat(data, "\n"):gsub("^%s+", ""):gsub("%s+$", "")
				if text ~= "" then
					notify(text)
				end
			end,
			on_exit = function(_, code)
				if code ~= 0 then
					notify("Gagal mengambil status " .. server, vim.log.levels.ERROR)
				end
			end,
		})
	end)
end

vim.api.nvim_create_user_command("BoxRun", M.box_run, {})
vim.api.nvim_create_user_command("BoxStatus", M.box_status, {})

return M
