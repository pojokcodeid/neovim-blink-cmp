-- mencegah treesitter belang-belang di bagian import
vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(args)
		local client = vim.lsp.get_client_by_id(args.data.client_id)
		if client and client.name == "gopls" then
			client.server_capabilities.semanticTokensProvider = nil
		end
	end,
})
