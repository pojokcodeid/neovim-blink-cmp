local M = {}

local active_win = nil
local active_buf = nil
local timer = nil

local DEFAULT_TIMEOUT = 3000

function M.close()
	if timer then
		timer:stop()
		timer:close()
		timer = nil
	end

	if active_win and vim.api.nvim_win_is_valid(active_win) then
		vim.api.nvim_win_close(active_win, true)
	end

	active_win = nil
	active_buf = nil
end

function M.show(message, level, timeout)
	M.close()

	level = level or vim.log.levels.INFO
	timeout = timeout or DEFAULT_TIMEOUT

	local lines = vim.split(tostring(message), "\n", {
		plain = true,
	})

	local width = 0

	for _, line in ipairs(lines) do
		width = math.max(width, vim.fn.strdisplaywidth(line))
	end

	width = math.min(math.max(width + 4, 35), vim.o.columns - 4)

	local height = #lines
	local buf = vim.api.nvim_create_buf(false, true)

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	vim.bo[buf].modifiable = false
	vim.bo[buf].bufhidden = "wipe"

	local win = vim.api.nvim_open_win(buf, false, {
		relative = "editor",
		width = width,
		height = height,
		row = math.max(1, math.floor((vim.o.lines - height) / 2)),
		col = math.max(0, math.floor((vim.o.columns - width) / 2)),
		style = "minimal",
		border = "rounded",
		zindex = 250,
		focusable = false,
	})

	local colors = {
		[vim.log.levels.ERROR] = "ErrorMsg",
		[vim.log.levels.WARN] = "WarningMsg",
		[vim.log.levels.INFO] = "DiagnosticInfo",
		[vim.log.levels.DEBUG] = "Comment",
	}

	vim.wo[win].winhighlight = "Normal:NormalFloat,FloatBorder:" .. (colors[level] or "FloatBorder")

	active_win = win
	active_buf = buf

	-- Auto close
	if timeout > 0 then
		timer = vim.uv.new_timer()

		timer:start(
			timeout,
			0,
			vim.schedule_wrap(function()
				M.close()
			end)
		)
	end

	return win
end

return M
