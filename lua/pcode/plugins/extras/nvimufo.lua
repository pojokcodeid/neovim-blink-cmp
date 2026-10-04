local M = { "kevinhwang91/nvim-ufo" }
M.event = "VeryLazy"
M.dependencies = {
	"kevinhwang91/promise-async",
	"luukvbaal/statuscol.nvim",
}
M.config = function()
	local builtin = require("statuscol.builtin")

	vim.o.mousemoveevent = true -- wajib supaya <MouseMove> terkirim

	local hover_win = nil -- window yang gutter-nya sedang di-hover
	local HOVER_MARGIN = 3 -- perlebar area hover beberapa kolom ke arah teks

	local function fold_segment(args)
		local hovered = hover_win == args.win
		local closed = vim.api.nvim_win_call(args.win, function()
			return vim.fn.foldclosed(args.lnum) ~= -1
		end)
		if hovered or closed then
			return builtin.foldfunc(args)
		end
		return " "
	end

	local function redraw_win(w)
		if w and vim.api.nvim_win_is_valid(w) then
			vim.api.nvim__redraw({ win = w, statuscolumn = true })
		end
	end

	vim.keymap.set({ "n", "v", "i", "o", "x" }, "<MouseMove>", function()
		local pos = vim.fn.getmousepos()
		local new_win = nil
		if pos.winid ~= 0 and pos.line > 0 then
			local info = vim.fn.getwininfo(pos.winid)[1]
			if info and pos.wincol <= info.textoff + HOVER_MARGIN then
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

	local cfg = {
		setopt = true,
		relculright = true,
		segments = {
			{ text = { fold_segment, " " }, click = "v:lua.ScFa", hl = "Comment" },
			{ text = { "%s" }, click = "v:lua.ScSa" },
			{ text = { builtin.lnumfunc, " " }, click = "v:lua.ScLa" },
		},
	}

	require("statuscol").setup(cfg)

	vim.o.foldcolumn = "1" -- '0' is not bad
	vim.o.foldlevel = 99 -- Using ufo provider need a large value, feel free to decrease the value
	vim.o.foldlevelstart = 99
	vim.o.foldenable = true
	-- vim.o.fillchars = [[eob: ,fold: ,foldopen:▾,foldsep: ,foldclose:▸]]
	vim.o.fillchars = [[eob: ,fold: ,foldopen:,foldsep: ,foldclose:]]

	-- Using ufo provider need remap `zR` and `zM`. If Neovim is 0.6.1, remap yourself
	vim.keymap.set("n", "zR", require("ufo").openAllFolds)
	vim.keymap.set("n", "zM", require("ufo").closeAllFolds)

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
				-- str width returned from truncate() may less than 2nd argument, need padding
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
		-- close_fold_kinds = { "imports", "comment" },
		provider_selector = function(bufnr, filetype, buftype)
			-- if you prefer treesitter provider rather than lsp,
			-- return ftMap[filetype] or {'treesitter', 'indent'}
			return ftMap[filetype]
			-- return { "treesitter", "indent" }

			-- refer to ./doc/example.lua for detail
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
	vim.keymap.set("n", "zm", require("ufo").closeFoldsWith) -- closeAllFolds == closeFoldsWith(0)
	vim.keymap.set("n", "K", function()
		local winid = require("ufo").peekFoldedLinesUnderCursor()
		if not winid then
			vim.lsp.buf.hover()
		end
	end)
end

return M
