return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      inlay_hints = { enabled = false },
      servers = {
        clangd = {
          cmd = {
            "clangd",
            "-header-insertion=never"
          },
          init_options = {
            fallbackFlags = {
              '--std=c++23'
            }
          },
          mason = false;
        },
      }
    }
  },
}
