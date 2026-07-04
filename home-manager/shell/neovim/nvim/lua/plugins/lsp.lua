return {
  {
    "neovim/nvim-lspconfig",
    enabled = not vim.g.vscode,
    opts = {
      inlay_hints = { enabled = false },
      servers = {
        clangd = {
          mason = false,
          cmd = {
            "clangd",
            "-header-insertion=never",
          },
          init_options = {
            fallbackFlags = {
              "--std=c++23",
            },
          },
        },
        ty = {
          mason = false,
          cmd = { "ty", "server" },
        },
      },
    },
  },
}
