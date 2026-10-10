-- ============================================================
-- compare_files.lua
-- Bandingkan 2 file dengan popup telescope, pilih folder masing-masing,
-- tampilkan alert persentase kecocokan, lalu buka diff side-by-side.
-- Butuh: telescope.nvim (+ plenary.nvim)
-- ============================================================

local M = {}

-- Atur false kalau file yang 100% sama tidak perlu dibuka dalam mode diff
local open_diff_if_identical = true

-- Lama alert tampil (milidetik)
local alert_timeout = 4000

-- vim.diff dinamai ulang menjadi vim.text.diff di Neovim versi baru
local diff_fn = (vim.text and vim.text.diff) or vim.diff

-- ------------------------------------------------------------
-- Alert: popup floating di pojok kanan atas, hilang otomatis
-- ------------------------------------------------------------
local function alert(lines, level, timeout)
	level = level or vim.log.levels.INFO
	timeout = timeout or alert_timeout

	local width = 0
	for _, l in ipairs(lines) do
		width = math.max(width, vim.fn.strdisplaywidth(l))
	end

	local padded = {}
	for _, l in ipairs(lines) do
		padded[#padded + 1] = " " .. l .. string.rep(" ", width - vim.fn.strdisplaywidth(l)) .. " "
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, padded)

	local win = vim.api.nvim_open_win(buf, false, {
		relative = "editor",
		anchor = "NE",
		row = 1,
		col = vim.o.columns - 1,
		width = width + 2,
		height = #padded,
		style = "minimal",
		border = "rounded",
		focusable = false,
		zindex = 250,
	})

	local border_hl = (level == vim.log.levels.WARN) and "WarningMsg" or "DiagnosticOk"
	vim.wo[win].winhl = "Normal:NormalFloat,FloatBorder:" .. border_hl

	vim.defer_fn(function()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end, timeout)
end

-- ------------------------------------------------------------
-- Langkah 1: tanya folder pencarian (input dengan default)
-- ------------------------------------------------------------
local function ask_cwd(title, default, on_done)
	vim.ui.input({
		prompt = title .. " - folder pencarian: ",
		default = default or vim.fn.getcwd(),
		completion = "dir",
	}, function(input)
		if not input or input == "" then
			return -- dibatalkan
		end

		local cwd = vim.fn.fnamemodify(vim.fn.expand(input), ":p")
		if vim.fn.isdirectory(cwd) == 0 then
			vim.notify("Folder tidak ditemukan: " .. cwd, vim.log.levels.ERROR)
			return
		end

		vim.schedule(function()
			on_done(cwd)
		end)
	end)
end

-- ------------------------------------------------------------
-- Langkah 2: popup telescope untuk memilih file di folder tsb
-- ------------------------------------------------------------
local function pick_file(title, cwd, on_select)
	local actions = require("telescope.actions")
	local state = require("telescope.actions.state")

	require("telescope.builtin").find_files({
		prompt_title = title .. "  [" .. cwd .. "]",
		cwd = cwd,
		attach_mappings = function(prompt_bufnr, _)
			actions.select_default:replace(function()
				local entry = state.get_selected_entry()
				actions.close(prompt_bufnr)
				if entry then
					local path = entry.path or vim.fn.fnamemodify(cwd .. "/" .. entry[1], ":p")
					on_select(path)
				end
			end)
			return true
		end,
	})
end

local function pick_file_with_cwd(title, default_cwd, on_select)
	ask_cwd(title, default_cwd, function(cwd)
		pick_file(title, cwd, function(path)
			on_select(path, cwd)
		end)
	end)
end

-- ------------------------------------------------------------
-- Hitung kemiripan 2 file (berbasis baris), hasil 0..100
-- Rumus: 2 * baris_sama / (total_baris_A + total_baris_B)
-- Return: persen, identik(boolean)
-- ------------------------------------------------------------
local function similarity(file1, file2)
	local a = vim.fn.readfile(file1)
	local b = vim.fn.readfile(file2)

	if #a == 0 and #b == 0 then
		return 100, true
	end

	local hunks = diff_fn(
		table.concat(a, "\n") .. "\n",
		table.concat(b, "\n") .. "\n",
		{ result_type = "indices", algorithm = "histogram" }
	)

	if #hunks == 0 then
		return 100, true
	end

	local changed_a = 0
	for _, h in ipairs(hunks) do
		changed_a = changed_a + h[2] -- h = { start_a, count_a, start_b, count_b }
	end

	local common = #a - changed_a
	local pct = 2 * common / (#a + #b) * 100
	-- dibulatkan ke bawah supaya tidak tampil "100%" kalau sebenarnya masih beda
	pct = math.floor(pct * 10) / 10
	return pct, false
end

-- ------------------------------------------------------------
-- Alur utama
-- ------------------------------------------------------------
function M.compare_files()
	pick_file_with_cwd("File 1", vim.fn.getcwd(), function(file1, cwd1)
		vim.schedule(function()
			-- default folder File 2 = folder yang dipilih untuk File 1
			pick_file_with_cwd("File 2", cwd1, function(file2)
				local name1 = vim.fn.fnamemodify(file1, ":t")
				local name2 = vim.fn.fnamemodify(file2, ":t")

				if vim.fn.resolve(file1) == vim.fn.resolve(file2) then
					vim.notify("File 1 dan File 2 adalah file yang sama.", vim.log.levels.WARN)
					return
				end

				local ok, pct, identical = pcall(similarity, file1, file2)
				if not ok then
					vim.notify("Gagal menghitung kemiripan: " .. tostring(pct), vim.log.levels.ERROR)
					pct, identical = nil, false
				end

				if identical and not open_diff_if_identical then
					alert({ "✅ Match 100%", name1 .. " = " .. name2 }, vim.log.levels.INFO)
					return
				end

				-- buka diff dulu, baru tampilkan alert (supaya tidak terhapus redraw)
				vim.cmd("tabnew " .. vim.fn.fnameescape(file1))
				vim.cmd("vert diffsplit " .. vim.fn.fnameescape(file2))

				vim.defer_fn(function()
					if identical then
						alert({ "✅ Match 100%", name1 .. " identik dengan " .. name2 }, vim.log.levels.INFO)
					elseif pct then
						alert({
							string.format("⚠️ Match %.1f%%", pct),
							name1 .. " vs " .. name2,
						}, vim.log.levels.WARN)
					end
				end, 100)
			end)
		end)
	end)
end

-- ------------------------------------------------------------
-- Color hilight
-- ------------------------------------------------------------
vim.opt.diffopt = {
	"internal",
	"filler",
	"closeoff",
	"vertical",
	"algorithm:histogram",
	"indent-heuristic",
	"linematch:60",
}

vim.api.nvim_set_hl(0, "DiffAdd", { bg = "#1e3a2a" })
vim.api.nvim_set_hl(0, "DiffDelete", { bg = "#3a1e1e", fg = "#5c2a2a" })
vim.api.nvim_set_hl(0, "DiffChange", { bg = "#2a2a3a" })
vim.api.nvim_set_hl(0, "DiffText", { bg = "#3d3d6b" })
-- ------------------------------------------------------------
-- Command & keymap
-- ------------------------------------------------------------
vim.api.nvim_create_user_command("CompareFiles", M.compare_files, {})
-- vim.keymap.set("n", "<leader>fd", M.compare_files, { desc = "Compare 2 files (popup)" })

return M
