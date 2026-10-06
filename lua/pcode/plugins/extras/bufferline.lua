-- Tutup buffer tanpa merusak layout window.
-- Terminal: proses dihentikan paksa; buffer biasa: ditolak jika belum disimpan.
local sidebar_ft = { ["neo-tree"] = true, NvimTree = true }

local function is_editor_win(win)
	if vim.api.nvim_win_get_config(win).relative ~= "" then
		return false -- floating window
	end
	return not sidebar_ft[vim.bo[vim.api.nvim_win_get_buf(win)].filetype]
end

local function close_buffer(bufnr)
	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local is_term = vim.bo[bufnr].buftype == "terminal"
	if not is_term and vim.bo[bufnr].modified then
		vim.notify("Buffer punya perubahan yang belum disimpan", vim.log.levels.WARN)
		return
	end

	-- Cari buffer pengganti: alternate (#), lalu buffer biasa mana pun yang terbuka
	local function usable(b)
		return b > 0 and b ~= bufnr and vim.api.nvim_buf_is_valid(b) and vim.bo[b].buflisted and vim.bo[b].buftype == ""
	end
	local replacement
	local alt = vim.fn.bufnr("#")
	if usable(alt) then
		replacement = alt
	else
		for _, b in ipairs(vim.api.nvim_list_bufs()) do
			if usable(b) then
				replacement = b
				break
			end
		end
	end

	-- Petakan window di tab saat ini
	local current = vim.api.nvim_get_current_win()
	local showing, others = {}, 0
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if vim.api.nvim_win_get_buf(win) == bufnr then
			table.insert(showing, win)
		elseif is_editor_win(win) then
			others = others + 1
		end
	end

	for i, win in ipairs(showing) do
		-- Split terminal ditutup jika masih ada window editor lain;
		-- selain itu isi window dengan buffer pengganti agar tidak kosong
		local close_it = is_term and (others > 0 or i > 1)
		if close_it then
			pcall(vim.api.nvim_win_close, win, true)
		else
			vim.api.nvim_win_call(win, function()
				if replacement then
					vim.api.nvim_win_set_buf(0, replacement)
				else
					vim.cmd("enew")
				end
			end)
		end
	end

	if is_term then
		local job = vim.b[bufnr].terminal_job_id
		if job then
			pcall(vim.fn.jobstop, job)
		end
	end
	pcall(vim.api.nvim_buf_delete, bufnr, { force = is_term })

	-- Kalau window yang sedang fokus ikut tertutup, pindah ke window editor
	if not vim.api.nvim_win_is_valid(current) then
		for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
			if is_editor_win(win) then
				vim.api.nvim_set_current_win(win)
				break
			end
		end
	end
end

local function close_current()
	local buf = vim.api.nvim_get_current_buf()
	if vim.bo[buf].buftype == "terminal" then
		close_buffer(buf)
	else
		require("pcode.user.buffer").bufremove()
	end
end

--- focus setelah embuka error list clik
local function focus_tab(buffer, button)
	if button ~= "l" then
		return
	end
	vim.schedule(function()
		-- Dari quickfix/trouble/dll: kembali ke window file sebelumnya
		if vim.bo.buftype ~= "" or not is_editor_win(vim.api.nvim_get_current_win()) then
			local prev = vim.fn.win_getid(vim.fn.winnr("#"))
			if prev ~= 0 and is_editor_win(prev) and vim.bo[vim.api.nvim_win_get_buf(prev)].buftype == "" then
				vim.api.nvim_set_current_win(prev)
			else
				for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
					if is_editor_win(win) and vim.bo[vim.api.nvim_win_get_buf(win)].buftype == "" then
						vim.api.nvim_set_current_win(win)
						break
					end
				end
			end
		end
		if vim.api.nvim_buf_is_valid(buffer.number) then
			vim.api.nvim_win_set_buf(0, buffer.number)
		end
	end)
end
return {
	"willothy/nvim-cokeline",
	branch = "main",
	event = { "BufRead", "BufNewFile" },
	opts = function()
		local truncate_text = function(text, max_length)
			if #text > max_length then
				local first_text = text:sub(1, max_length - 10)
				local end_text = text:sub(#text - 7, #text)
				return first_text .. "..." .. end_text
			else
				return text
			end
		end

		local yellow = vim.g.terminal_color_3
		local hlgroups = require("cokeline.hlgroups")
		local hl_attr = hlgroups.get_hl_attr
		return {
			sidebar = {
				filetype = { "NvimTree", "neo-tree" },
				components = {
					{
						text = " ",
						bg = hl_attr("Normal", "bg"),
					},
					{
						text = function(buf)
							if buf.filetype == "neo-tree" then
								return "Explorer"
							else
								return vim.fn.fnamemodify(vim.fn.getcwd(), ":t") or "Explorer"
							end
						end,
						fg = yellow,
						bg = function()
							return hl_attr("Normal", "bg")
						end,
						bold = true,
					},
				},
			},
			components = {
				{
					text = " ",
					bg = hl_attr("Normal", "bg"),
				},
				{
					text = "",
					fg = function(buffer)
						if buffer.is_focused then
							return hl_attr("ColorColumnTab", "bg")
						else
							return hl_attr("NormalTab", "bg")
						end
					end,
					bg = hl_attr("Normal", "bg"),
				},
				{
					text = function(buffer)
						return buffer.devicon.icon
					end,
					fg = function(buffer)
						return buffer.devicon.color
					end,
					on_click = function(_, _, button, _, buffer)
						focus_tab(buffer, button)
					end,
					bg = function(buffer)
						return buffer.is_focused and hl_attr("ColorColumnTab", "bg") or hl_attr("NormalTab", "bg")
					end,
				},
				{
					text = " ",
					on_click = function(_, _, button, _, buffer)
						focus_tab(buffer, button)
					end,
					bg = function(buffer)
						return buffer.is_focused and hl_attr("ColorColumnTab", "bg") or hl_attr("NormalTab", "bg")
					end,
				},
				{
					text = function(buffer)
						return truncate_text(buffer.filename, 22) .. " "
					end,
					style = function(buffer)
						return buffer.is_focused and "bold" or nil
					end,
					on_click = function(_, _, button, _, buffer)
						focus_tab(buffer, button)
					end,
					bg = function(buffer)
						return buffer.is_focused and hl_attr("ColorColumnTab", "bg") or hl_attr("NormalTab", "bg")
					end,
				},
				{
					text = "󰅖",
					-- BARU: ganti delete_buffer_on_left_click dengan on_click kustom
					on_click = function(_, _, button, _, buffer)
						if button ~= "l" then
							return
						end
						local bufnr = buffer.number
						vim.schedule(function()
							close_buffer(bufnr)
						end)
					end,
					bg = function(buffer)
						return buffer.is_focused and hl_attr("ColorColumnTab", "bg") or hl_attr("NormalTab", "bg")
					end,
				},
				{
					text = "",
					fg = function(buffer)
						if buffer.is_focused then
							return hl_attr("ColorColumnTab", "bg")
						else
							return hl_attr("NormalTab", "bg")
						end
					end,
					bg = hl_attr("Normal", "bg"),
				},
			},
		}
	end,
	keys = {
		{ "<leader>b", "", desc = "Buffers", mode = "n" },
		{
			"<Leader>bp",
			"<Plug>(cokeline-switch-prev)",
			desc = "Focus Previous buffer",
			mode = "n",
		},
		{
			"<Leader>bn",
			"<Plug>(cokeline-switch-next)",
			desc = "Focus next buffer",
			mode = "n",
		},
		{
			"<leader>bb",
			function()
				require("telescope.builtin").buffers(require("telescope.themes").get_dropdown({ previewer = false }))
			end,
			desc = "All Buffer",
			mode = "n",
		},
		{
			"<leader>bc",
			function()
				require("pcode.user.buffer").bufremove()
			end,
			desc = "Close current buffer",
			mode = "n",
		},
		{
			"<S-Tab>",
			"<Plug>(cokeline-focus-prev)",
			desc = "Focus previous buffer",
			mode = "n",
		},
		{
			"<Tab>",
			"<Plug>(cokeline-focus-next)",
			desc = "Focus buffer Next",
			mode = "n",
		},
		{
			"<S-PageUp>",
			"<Plug>(cokeline-switch-prev)",
			desc = "Switch to previous buffer",
			mode = "n",
		},
		{
			"<S-PageDown>",
			"<Plug>(cokeline-switch-next)",
			desc = "Switch to next buffer",
			mode = "n",
		},
		{
			"<S-t>",
			function()
				require("pcode.user.buffer").bufremove()
			end,
			desc = "Close Current Buffer",
			mode = "n",
		},
	},
}
