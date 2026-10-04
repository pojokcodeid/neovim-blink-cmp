local M = { "kevinhwang91/nvim-ufo" }
M.event = "VeryLazy"
M.dependencies = {
	"kevinhwang91/promise-async",
	"luukvbaal/statuscol.nvim",
}

M.config = function()
	local builtin = require("statuscol.builtin")

	-- Wajib supaya <MouseMove> terkirim ke Neovim
	vim.o.mousemoveevent = true

	-- Window yang gutter-nya sedang di-hover
	local hover_win = nil
	-- Perlebar area hover beberapa kolom ke arah teks (mouse cepat sering melewati gutter)
	local HOVER_MARGIN = 3
	-- Filetype yang diabaikan
	local ignored_ft = {
		NvimTree = true,
		["neo-tree"] = true,
		help = true,
		dashboard = true,
		lazy = true,
		mason = true,
		Trouble = true,
		qf = true,
	}

	local function fold_segment(args)
		local fc = vim.wo[args.win].foldcolumn
		-- window tanpa foldcolumn: jangan return apa-apa supaya lebar tidak berubah
		if fc == "0" then
			return ""
		end

		local hovered = hover_win == args.win
		-- fold yang sedang tertutup tetap ditampilkan (seperti VSCode).
		-- Hapus kondisi `closed` kalau mau benar-benar hanya saat hover.
		local closed = vim.api.nvim_win_call(args.win, function()
			return vim.fn.foldclosed(args.lnum) ~= -1
		end)

		if hovered or closed then
			return builtin.foldfunc(args)
		end
		-- placeholder selebar foldcolumn supaya angka baris tidak bergeser
		return (" "):rep(tonumber(fc) or 1)
	end

	local function redraw_win(w)
		if not (w and vim.api.nvim_win_is_valid(w)) then
			return
		end
		if vim.api.nvim__redraw then
			vim.api.nvim__redraw({ win = w, statuscolumn = true })
		else
			vim.cmd("redraw!")
		end
	end

	vim.keymap.set({ "n", "v", "i", "o", "x" }, "<MouseMove>", function()
		local pos = vim.fn.getmousepos()
		local new_win = nil

		if pos.winid ~= 0 and pos.line > 0 then
			local buf = vim.api.nvim_win_get_buf(pos.winid)
			local ft = vim.bo[buf].filetype
			local bt = vim.bo[buf].buftype
			local ignored = bt ~= "" or ignored_ft[ft]
			local info = vim.fn.getwininfo(pos.winid)[1]
			if not ignored and info and pos.wincol <= info.textoff + HOVER_MARGIN then
				new_win = pos.winid
			end
		end

		if new_win ~= hover_win then
			local old = hover_win
			hover_win = new_win
			redraw_win(old)
			redraw_win(new_win)
		end
		return ""
	end, { expr = true, silent = true })

	require("statuscol").setup({
		setopt = true,
		relculright = true,
		ft_ignore = vim.tbl_keys(ignored_ft),
		bt_ignore = { "nofile", "terminal", "prompt" },
		segments = {
			{ text = { fold_segment, " " }, click = "v:lua.ScFa", hl = "Comment" },
			{ text = { "%s" }, click = "v:lua.ScSa" },
			{ text = { builtin.lnumfunc, " " }, click = "v:lua.ScLa" },
		},
	})

	vim.o.foldcolumn = "1"
	vim.o.foldlevel = 99
	vim.o.foldlevelstart = 99
	vim.o.foldenable = true
	vim.o.fillchars = [[eob: ,fold: ,foldopen:,foldsep: ,foldclose:]]

	-- Fold text handler
	local handler = function(virtText, lnum, endLnum, width, truncate)
		local newVirtText = {}
		local suffix = (" 󰡏 %d "):format(endLnum - lnum)
		local sufWidth = vim.fn.strdisplaywidth(suffix)
		local targetWidth = width - sufWidth
		local curWidth = 0
		for _, chunk in ipairs(virtText) do
			local chunkText = chunk[1]
			local chunkWidth = vim.fn.strdisplaywidth(chunkText)
			if targetWidth > curWidth + chunkWidth then
				table.insert(newVirtText, chunk)
			else
				chunkText = truncate(chunkText, targetWidth - curWidth)
				local hlGroup = chunk[2]
				table.insert(newVirtText, { chunkText, hlGroup })
				chunkWidth = vim.fn.strdisplaywidth(chunkText)
				-- str width returned from truncate() may be less than 2nd argument, need padding
				if curWidth + chunkWidth < targetWidth then
					suffix = suffix .. (" "):rep(targetWidth - curWidth - chunkWidth)
				end
				break
			end
			curWidth = curWidth + chunkWidth
		end
		table.insert(newVirtText, { suffix, "MoreMsg" })
		return newVirtText
	end

	local ftMap = {
		-- typescriptreact = { "lsp", "treesitter" },
		-- python = { "indent" },
		-- git = "",
	}

	require("ufo").setup({
		fold_virt_text_handler = handler,
		close_fold_kinds = {},
		provider_selector = function(bufnr, filetype, buftype)
			return ftMap[filetype]
		end,
		preview = {
			win_config = {
				border = { "", "─", "", "", "", "─", "", "" },
				winhighlight = "Normal:Folded",
				winblend = 0,
			},
			mappings = {
				scrollU = "<C-k>",
				scrollD = "<C-j>",
				jumpTop = "[",
				jumpBot = "]",
			},
		},
	})

	vim.keymap.set("n", "zR", require("ufo").openAllFolds)
	vim.keymap.set("n", "zM", require("ufo").closeAllFolds)
	vim.keymap.set("n", "zr", require("ufo").openFoldsExceptKinds)
	vim.keymap.set("n", "zm", require("ufo").closeFoldsWith)
	vim.keymap.set("n", "K", function()
		local winid = require("ufo").peekFoldedLinesUnderCursor()
		if not winid then
			vim.lsp.buf.hover()
		end
	end)
end

return M
