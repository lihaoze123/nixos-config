return {
  {
    "folke/which-key.nvim",
    enabled = not vim.g.vscode,
    opts = {
      spec = {
        {
          mode = { "n", "v" },
          { "<leader>C", group = "Competitest" },
        },
      },
    },
  },
}
