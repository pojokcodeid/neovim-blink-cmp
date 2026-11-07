-- ============================================================================
-- Keymaps Configuration
-- ============================================================================
local keymap = vim.keymap.set
local opts = { noremap = true, silent = true }

-- Remap space sebagai leader key
keymap("", "<Space>", "<Nop>", opts)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- ============================================================================
-- 1. General & File Management
-- ============================================================================
-- Simpan file cepat (Ctrl + S) di mode Normal, Insert, Visual, Visual Block
for _, mode in ipairs({ "n", "i", "v", "x" }) do
	keymap(mode, "<C-s>", "<cmd>silent! w<cr>", { desc = "Save file", unpack(opts) })
end

-- Tutup window saat ini dengan 'q'
keymap("n", "q", "<cmd>q<cr>", { desc = "Close window", unpack(opts) })

-- Keluar mode insert cepat dengan jk atau kj
keymap("i", "jk", "<ESC>", opts)
keymap("i", "kj", "<ESC>", opts)

-- ============================================================================
-- 2. Window & Buffer Navigation
-- ============================================================================
-- Pindah window (Ctrl + hjkl)
keymap("n", "<C-h>", "<C-w>h", { desc = "Move to left window", unpack(opts) })
keymap("n", "<C-j>", "<C-w>j", { desc = "Move to down window", unpack(opts) })
keymap("n", "<C-k>", "<C-w>k", { desc = "Move to up window", unpack(opts) })
keymap("n", "<C-l>", "<C-w>l", { desc = "Move to right window", unpack(opts) })

-- Navigasi antar buffer (Shift + h / l dan Shift + Arrow)
keymap("n", "<S-l>", ":bnext<CR>", { desc = "Next buffer", unpack(opts) })
keymap("n", "<S-Left>", "<Esc>:bnext<CR>", { desc = "Next buffer", unpack(opts) })
keymap("n", "<S-h>", ":bprevious<CR>", { desc = "Previous buffer", unpack(opts) })
keymap("n", "<S-Right>", "<Esc>:bprevious<CR>", { desc = "Previous buffer", unpack(opts) })

-- Navigasi Quickfix list
keymap("n", "]q", "<cmd>cnext<cr>zz", { desc = "Next quickfix item" })
keymap("n", "[q", "<cmd>cprev<cr>zz", { desc = "Prev quickfix item" })

-- ============================================================================
-- 3. Clipboard, Selection & Undo
-- ============================================================================
-- Select All (Ctrl + A)
keymap("n", "<C-a>", "gg0v$G", { desc = "Select all", unpack(opts) })
keymap("i", "<C-a>", "<esc>gg0v$G", { desc = "Select all", unpack(opts) })

-- Copy ke clipboard sistem (Ctrl + C)
keymap("n", "<C-c>", '"+y', { desc = "Copy to system clipboard", unpack(opts) })
keymap("v", "<C-c>", '"+y', { desc = "Copy to system clipboard", unpack(opts) })
keymap("x", "<C-c>", '"+y', { desc = "Copy to system clipboard", unpack(opts) })

-- Paste dari clipboard sistem (Ctrl + V)
keymap("n", "<C-v>", '"+P', { desc = "Paste from system clipboard", unpack(opts) })
keymap("v", "<C-v>", '"+P', { desc = "Paste from system clipboard", unpack(opts) })
keymap("x", "<C-v>", '"+P', { desc = "Paste from system clipboard", unpack(opts) })
keymap("i", "<C-v>", "<esc>pa<Left>", { desc = "Paste from system clipboard", unpack(opts) })

-- Undo (Ctrl + Z)
keymap("n", "<C-z>", "<cmd>undo<CR>", { desc = "Undo", unpack(opts) })
keymap("i", "<C-z>", "<esc><cmd>undo<CR>", { desc = "Undo", unpack(opts) })
keymap("v", "<C-z>", "<esc><cmd>undo<CR>", { desc = "Undo", unpack(opts) })
keymap("x", "<C-z>", "<esc><cmd>undo<CR>", { desc = "Undo", unpack(opts) })

-- ============================================================================
-- 4. Line & Block Editing
-- ============================================================================
-- Duplikasi baris (Shift + Up / Down dan Shift + Alt + Up / Down)
for _, mode in ipairs({ "i", "v", "n", "x" }) do
	keymap(mode, "<S-Down>", "<cmd>t.<cr>", opts)
	keymap(mode, "<S-Up>", "<cmd>t -1<cr>", opts)
	keymap(mode, "<S-M-Down>", "<cmd>t.<cr>", opts)
	keymap(mode, "<S-M-Up>", "<cmd>t -1<cr>", opts)
end

-- Duplikasi selection pada Visual Block
keymap("x", "<S-Down>", ":'<,'>t'><cr>", opts)
keymap("x", "<S-M-Down>", ":'<,'>t'><cr>", opts)
keymap("x", "<S-Up>", ":'<,'>t-1<cr>", opts)
keymap("x", "<S-M-Up>", ":'<,'>t-1<cr>", opts)

-- Geser baris ke atas / bawah (Alt + Up / Down)
keymap("x", "<A-Down>", ":move '>+1<CR>gv-gv", opts)
keymap("n", "<A-Down>", ":move '>+1<CR>gv-gv", opts)
keymap("i", "<A-Down>", ":move '>+1<CR>gv-gv", opts)
keymap("x", "<A-Up>", ":move '<-2<CR>gv-gv", opts)
keymap("n", "<A-Up>", ":move '<-2<CR>gv-gv", opts)
keymap("i", "<A-Up>", ":move '<-2<CR>gv-gv", opts)

keymap("n", "<M-Down>", "<cmd>m+<cr>", opts)
keymap("i", "<M-Down>", "<cmd>m+<cr>", opts)
keymap("n", "<M-Up>", "<cmd>m-2<cr>", opts)
keymap("i", "<M-Up>", "<cmd>m-2<cr>", opts)

-- Tetap dalam indent mode saat indenting di Visual Mode
keymap("v", "<", "<gv", opts)
keymap("v", ">", ">gv", opts)

-- ============================================================================
-- 5. Commenting (Ctrl + /)
-- ============================================================================
-- Visual block comment
keymap("x", "<C-_>", function()
	vim.api.nvim_feedkeys("gb", "v", true)
end, { desc = "Toggle block comment", unpack(opts) })

-- Helper untuk comment normal & insert mode
local function toggle_comment_with_position()
	vim.api.nvim_feedkeys("gcc", "v", true)
	vim.schedule(function()
		local row = vim.fn.line(".") - 1
		local col = #vim.fn.getline(".")
		vim.api.nvim_win_set_cursor(0, { row + 1, col })
		vim.api.nvim_feedkeys("i", "v", true)
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Right><leader>", true, false, true), "n", true)
	end)
end

keymap("n", "<C-_>", toggle_comment_with_position, { desc = "Toggle line comment", unpack(opts) })
keymap("i", "<C-_>", function()
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<BS><Tab><esc>", true, false, true), "n", true)
	toggle_comment_with_position()
end, { desc = "Toggle line comment", unpack(opts) })

-- ============================================================================
-- 6. File Explorer (NvimTree) Toggle via 'f'
-- ============================================================================
local function tree_win()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(win)
		if vim.bo[buf].filetype == "NvimTree" then
			return win
		end
	end
end

local function refreshTree()
	local ok, api = pcall(require, "nvim-tree.api")
	if not ok then
		return
	end

	if tree_win() then
		api.tree.close()
	else
		api.tree.open({ find_file = true, focus = true })
		api.tree.reload()
	end
end

keymap("n", "f", refreshTree, { desc = "Toggle File Tree", unpack(opts) })

-- ============================================================================
-- 7. Search & Replace Terpilih (Visual Mode)
-- ============================================================================
-- Cari teks terpilih dengan menekan '/' di mode Visual
keymap("v", "/", function()
	local saved_reg = vim.fn.getreg("v")
	vim.cmd('normal! "vy')
	local selected = vim.fn.getreg("v")
	vim.fn.setreg("v", saved_reg)

	if not selected or selected == "" then
		return
	end

	local escaped = vim.fn.escape(selected, "/\\.*$^~[]"):gsub("\n", "\\n")
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
	vim.fn.feedkeys("/" .. escaped)
end, { desc = "Search selected text", unpack(opts) })

-- Ganti semua kemunculan teks terpilih (Ctrl + H di Visual Mode)
local function replace_selected_text()
	local mode = vim.fn.mode()
	if mode ~= "v" and mode ~= "V" and mode ~= "\22" then
		vim.notify("Blok teks dulu (visual mode) sebelum menekan Ctrl+H", vim.log.levels.WARN)
		return
	end

	vim.cmd('normal! "vy')
	local selected = vim.fn.getreg("v")
	if not selected or selected == "" then
		return
	end

	local function escape_pattern(str)
		return (str:gsub("[%^%$%.%*%~%[%]/\\]", "\\%0"))
	end

	local escaped_selected = escape_pattern(selected)

	-- Dialog 1: Pilih case sensitive / insensitive
	vim.ui.select(
		{ "Case sensitive", "Case insensitive" },
		{ prompt = "Mode pencarian untuk '" .. selected .. "':" },
		function(choice)
			if not choice then
				return
			end

			local case_flag = (choice == "Case sensitive") and "\\C" or "\\c"

			-- Dialog 2: Masukkan teks pengganti
			vim.ui.input({ prompt = "Ganti '" .. selected .. "' dengan (" .. choice .. "): " }, function(replacement)
				if replacement == nil then
					return
				end

				local escaped_replacement = replacement:gsub("[&\\]", "\\%0")
				local ok, err = pcall(function()
					vim.cmd(string.format("%%s/%s%s/%s/g", escaped_selected, case_flag, escaped_replacement))
				end)

				if ok then
					vim.notify("Replace selesai (" .. choice .. ").", vim.log.levels.INFO)
				else
					vim.notify("Gagal replace: " .. tostring(err), vim.log.levels.ERROR)
				end
			end)
		end
	)
end

keymap("v", "<C-h>", replace_selected_text, {
	desc = "Replace all: teks terpilih -> input baru (dengan opsi case)",
	unpack(opts),
})

-- ============================================================================
-- 8. Background Runner (BgRun) Shortcuts
-- ============================================================================
keymap("n", "<leader>j", "", { desc = "Run" })
keymap("n", "<leader>jr", "<cmd>BgRun<cr>", { desc = "BG run" })
keymap("n", "<leader>jl", "<cmd>BgList<cr>", { desc = "BG status/history" })
keymap("n", "<leader>jg", "<cmd>BgLog<cr>", { desc = "BG log" })
keymap("n", "<leader>js", "<cmd>BgStop<cr>", { desc = "BG stop" })

-- ============================================================================
-- 9. External Tools & Live Server
-- ============================================================================
keymap("n", "<A-l>", "<cmd>terminal live-server<cr>", { desc = "Start live-server", unpack(opts) })
