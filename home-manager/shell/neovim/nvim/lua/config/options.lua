-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.g.autoformat = false

local opt = vim.opt

opt.tabstop = 4
opt.shiftwidth = 4
opt.softtabstop = 4
opt.autoindent = true
opt.smartindent = true
opt.smarttab = true
opt.expandtab = true

if vim.g.neovide then
    vim.o.guifont = "FiraCode Nerd Font:h18"
    vim.g.neovide_input_ime = false
end
