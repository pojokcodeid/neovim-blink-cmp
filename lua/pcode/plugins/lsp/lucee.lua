-- lua/pcode/plugins/lsp/lucee.lua
-- download dari https://github.com/cfmleditor/cfmleditor-lsp
-- pastikan file sudah di allow
local binary_path = vim.fn.expand("~/.config/nvim/lua/pcode/plugins/lsp/lib/cfmleditor-lsp")
return {
	cmd = { binary_path },
	filetypes = { "cfml", "cfscript" },
	single_file_support = true,
	root_markers = { "Application.cfc", ".git", ".vscode" },
	settings = {},
}
