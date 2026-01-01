-- activate config spesific languages
pcode.lang = {
	angular = false,
	cpp = false,
	deno = false,
	golang = false,
	java = false,
	java2 = false,
	java3 = false,
	java4 = false,
	javascript = false,
	kotlin = false,
	markdown = false,
	php = false,
	prisma = false,
	python = false,
	rust = false,
	sql = false,
	tailwind = false,
}
-- activate config extras
pcode.extras = {
	autosave = false,
	bigfiles = false,
	bufferline = true,
	cheatsheet = false,
	codeium = false,
	codeiumnvim = false,
	colorizer = false,
	dap = false,
	deviconcolor = false,
	dressing = true,
	fidget = false,
	illuminate = false,
	indentscupe = false,
	liveserver = false,
	minianimate = false,
	navic = true,
	neocodeium = true,
	neoscroll = false,
	nvimmenu = false,
	nvimufo = false,
	rainbowdelimiters = true,
	refactoring = false,
	rest = false,
	scrollview = false,
	showkeys = true,
	smartsplit = false,
	telescopediff = false,
	telescopetreesiterinfo = false,
	tinydignostic = false,
	treesittercontex = false,
	verticalcolumn = false,
	visualmulti = false,
	yanky = false,
	zenmode = false,
}
-- activate config themes
	-- note: open remark only one
	-- **:: eva theme ::** --
	-- evatheme = "Eva-Dark",
	-- evatheme = "Eva-Dark-Italic",
	-- evatheme = "Eva-Dark-Bold",
	-- evatheme = "Eva-Light",
	--
	-- **:: dracula theme ::** --
	-- dracula = "dracula",
	-- dracula = "dracula-soft",
	--
	-- **:: onedarkpro theme ::** --
	-- onedarkpro = "onedark",
	-- onedarkpro = "onedark_vivid",
	-- onedarkpro = "onedark_dark",
	--
	-- **:: jetbrains theme ::** --
	-- jetbrains = "darcula-dark",
	--
	-- **:: sublimetext theme ::** --
	-- sublimetext = "juliana",
	--
	-- **:: tokyonight theme ::** --
	-- tokyonight = "tokyonight-night",
	-- tokyonight = "tokyonight-storm",
	-- tokyonight = "tokyonight-day",
	-- tokyonight = "tokyonight-moon",
	--
	-- **:: catppuccin theme ::** --
	-- catppuccin = "catppuccin",
	-- catppuccin = "catppuccin-latte",
	-- catppuccin = "catppuccin-frappe",
	-- catppuccin = "catppuccin-macchiato",
	-- catppuccin = "catppuccin-macchiato",
	--
	-- **:: gruvbox theme ::** --
	-- gruvbox = "gruvbox",
	--
	-- **:: github theme ::** --
	-- github = "github_dark_dimmed",

pcode.themes = {
  dracula = "dracula"
}
-- activate config transparent_bg
pcode.transparent = false
pcode.localcode = true
pcode.snippets_path = vim.fn.stdpath("config") .. "/mysnippets"
pcode.use_nvimtree = true
pcode.nvimtree_float = false
