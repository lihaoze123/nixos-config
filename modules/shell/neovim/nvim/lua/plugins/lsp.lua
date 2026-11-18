return {
  {
    "neovim/nvim-lspconfig",
    enabled = not vim.g.vscode,
    init = function()
      -- nvim-lspconfig forwards these arguments to the JDTLS launcher.
      local lombok_jar = vim.fn.stdpath("data") .. "/mason/share/jdtls/lombok.jar"
      local jvm_args = vim.env.JDTLS_JVM_ARGS or ""
      vim.env.JDTLS_JVM_ARGS = vim.trim(jvm_args .. " -javaagent:" .. lombok_jar)
    end,
  },
}
