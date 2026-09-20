-- Hapus alert / print sebelumnya

-- Force cindent & indentexpr khusus buffer CFML
vim.bo.cindent = true
vim.bo.smartindent = false
vim.bo.indentexpr = "cindent(v:lnum)"

-- Formatting tab/spasi
vim.bo.expandtab = true
vim.bo.shiftwidth = 4
vim.bo.tabstop = 4

-- Align kurung kurawal { } & pemicu kata kunci
vim.bo.cinoptions = "{0,}0,j1,J1"
vim.bo.cinwords = "component,function,if,else,for,while,switch,try,catch"
