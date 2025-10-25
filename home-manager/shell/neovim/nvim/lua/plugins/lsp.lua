return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      inlay_hints = { enabled = false },
      servers = {
        clangd = {
          mason = false;
          cmd = {
            "clangd",
            "-header-insertion=never"
          },
          init_options = {
            fallbackFlags = {
              '--std=c++23'
            }
          },
        },
      }
    }
  },
}
