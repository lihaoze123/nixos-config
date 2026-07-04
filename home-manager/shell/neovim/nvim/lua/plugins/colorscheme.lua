return {
  { "Mofiqul/dracula.nvim", enabled = not vim.g.vscode },
  {
    "LazyVim/LazyVim",
    opts = function(_, opts)
      opts.colorscheme = vim.g.vscode and function() end or "dracula"
    end,
  },
}
