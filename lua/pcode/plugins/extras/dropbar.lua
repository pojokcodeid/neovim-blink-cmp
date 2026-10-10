local function icon(codepoint)
	return vim.fn.nr2char(codepoint) .. " "
end
return {
	"Bekaboo/dropbar.nvim",
	event = "VeryLazy",
	dependencies = {
		{
			"nvim-telescope/telescope-fzf-native.nvim",
			build = "make",
		},
	},
	opts = {
		icons = {
			kinds = {
				dir_icon = function(_)
					return " ", "NvimTreeFolderIcon"
				end,
				symbols = {
					Array = "󰅪 ",
					BlockMappingPair = "󰅩 ",
					Boolean = "󰨙 ",
					BreakStatement = "󰙧 ",
					Call = "󰃷 ",
					CaseStatement = "󱃙 ",
					Class = " ",
					Color = "󰏘 ",
					Constant = " ",
					Constructor = " ",
					ContinueStatement = "→ ",
					Copilot = " ",
					Declaration = "󰙠 ",
					Delete = "󰩺 ",
					DoStatement = "󰑖 ",
					Element = "󰅩 ",
					Enum = " ",
					EnumMember = " ",
					Event = " ",
					Field = " ",
					File = "󰈔 ",
					Folder = " ",
					ForStatement = "󰑖 ",
					Function = "󰊕 ",
					GotoStatement = "󰁔 ",
					Identifier = "󰀫 ",
					IfStatement = "󰇉 ",
					Interface = " ",
					Keyword = "󰌋 ",
					List = "󰅪 ",
					Log = "󰦪 ",
					Lsp = " ",
					Macro = "󰁌 ",
					MarkdownH1 = "󰉫 ",
					MarkdownH2 = "󰉬 ",
					MarkdownH3 = "󰉭 ",
					MarkdownH4 = "󰉮 ",
					MarkdownH5 = "󰉯 ",
					MarkdownH6 = "󰉰 ",
					Method = "󰆧 ",
					Module = "󰏗 ",
					Namespace = "󰅩 ",
					Null = "󰢤 ",
					Number = "󰎠 ",
					Object = "󰅩 ",
					Operator = "󰆕 ",
					Package = "󰆦 ",
					Pair = "󰅪 ",
					Property = " ",
					Reference = "󰦾 ",
					Regex = " ",
					Repeat = "󰑖 ",
					Return = "󰌑 ",
					Rule = "󰅩 ",
					RuleSet = "󰅩 ",
					Scope = "󰅩 ",
					Section = "󰅩 ",
					Snippet = "󰩫 ",
					Specifier = "󰦪 ",
					Statement = "󰅩 ",
					String = "󰉾 ",
					Struct = " ",
					SwitchStatement = "󰺟 ",
					Table = "󰅩 ",
					Terminal = " ",
					Text = " ",
					Type = " ",
					TypeParameter = "󰆩 ",
					Unit = " ",
					Value = "󰎠 ",
					Variable = "󰀫 ",
					WhileStatement = "󰑖 ",
				},
			},
		},
		bar = {
			padding = { left = 2, right = 2 }, -- margin kiri/kanan breadcrumb
		},
		menu = {
			preview = false,
			quick_navigation = true,
			scrollbar = { enable = false },
			entry = {
				padding = { left = 1, right = 2 }, -- margin teks di dalam menu
			},
			win_configs = {
				border = "rounded",
			},
		},
	},
	config = function(_, opts)
		require("dropbar").setup(opts)

		local function get(name)
			return vim.api.nvim_get_hl(0, { name = name, link = false })
		end

		-- campur dua warna (0xRRGGBB), a = 0..1
		local function blend(c1, c2, a)
			local function ch(c, s)
				return math.floor(c / 2 ^ s) % 256
			end
			local r = ch(c1, 16) * (1 - a) + ch(c2, 16) * a
			local g = ch(c1, 8) * (1 - a) + ch(c2, 8) * a
			local b = ch(c1, 0) * (1 - a) + ch(c2, 0) * a
			return math.floor(r) * 65536 + math.floor(g) * 256 + math.floor(b)
		end

		-- timpa sebagian atribut, pertahankan sisanya (fg dll.)
		local function patch(name, attrs)
			local cur = get(name)
			vim.api.nvim_set_hl(0, name, vim.tbl_extend("force", cur, attrs))
		end

		local function set_hl()
			local normal = get("Normal")
			local comment = get("Comment")
			local visual = get("Visual")

			local bg = normal.bg or 0x282A36
			local dim = comment.fg
			-- warna hover halus: 35% menuju warna Visual
			local hover = blend(bg, visual.bg or 0x3b3f52, 0.35)

			vim.api.nvim_set_hl(0, "DropBarMenuNormalFloat", { bg = bg })
			vim.api.nvim_set_hl(0, "DropBarMenuFloatBorder", { fg = dim, bg = bg })

			-- semua bagian baris hover memakai bg yang sama
			for _, name in ipairs({
				"DropBarMenuHoverEntry",
				"DropBarMenuHoverIcon",
				"DropBarMenuHoverSymbol",
				"DropBarMenuCurrentContext",
			}) do
				-- reverse = false: cegah warna ikon terbalik (bawaan HoverIcon = reverse)
				patch(name, { bg = hover, reverse = false })
			end

			-- panah ">" redup dan tanpa background.
			-- PENTING: kode dropbar memakai nama huruf kecil "dropbarIconUIIndicator",
			-- sedangkan dokumentasi menulis "DropBarIconUIIndicator". Timpa dua-duanya.
			for _, name in ipairs({
				"dropbarIconUIIndicator",
				"DropBarIconUIIndicator",
				"DropBarIconUISeparator",
				"DropBarIconUISeparatorMenu",
			}) do
				vim.api.nvim_set_hl(0, name, { fg = dim, bg = "NONE" })
			end

			-- breadcrumb hover: lembut, bukan blok abu-abu tebal
			patch("DropBarCurrentContext", { bg = hover })
			patch("DropBarHover", { bg = hover })
		end

		set_hl()
		vim.api.nvim_create_autocmd("ColorScheme", {
			callback = function()
				vim.schedule(set_hl)
			end,
		})

		-- Sembunyikan kursor saat berada di menu dropbar
		local saved_guicursor

		local function hide_cursor()
			vim.api.nvim_set_hl(0, "DropBarHiddenCursor", { blend = 100, nocombine = true })
			if saved_guicursor == nil then
				saved_guicursor = vim.o.guicursor
			end
			vim.o.guicursor = "a:DropBarHiddenCursor"
		end

		local function restore_cursor()
			if saved_guicursor ~= nil then
				vim.o.guicursor = saved_guicursor
				saved_guicursor = nil
			end
		end

		local group = vim.api.nvim_create_augroup("DropbarHideCursor", { clear = true })

		vim.api.nvim_create_autocmd({ "BufEnter", "FileType" }, {
			group = group,
			callback = function(ev)
				if vim.bo[ev.buf].filetype == "dropbar_menu" then
					hide_cursor()
				end
			end,
		})

		vim.api.nvim_create_autocmd({ "BufLeave", "BufWinLeave", "WinClosed" }, {
			group = group,
			callback = function(ev)
				if vim.bo[ev.buf].filetype == "dropbar_menu" then
					-- schedule agar tidak bentrok saat pindah antar submenu
					vim.schedule(function()
						if vim.bo[vim.api.nvim_get_current_buf()].filetype ~= "dropbar_menu" then
							restore_cursor()
						end
					end)
				end
			end,
		})
	end,
}
