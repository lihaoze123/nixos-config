local ok, vscode = pcall(require, "vscode")
if not ok then
  return
end

if type(vscode.notify) == "function" then
  vim.notify = vscode.notify
end

if vim.g.vscode_clipboard then
  vim.g.clipboard = vim.g.vscode_clipboard
end

local function map(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, { noremap = true, silent = true, desc = desc })
end

local function call(command, opts, timeout)
  return function()
    vscode.call(command, opts, timeout)
  end
end

-- Keep common LazyVim muscle memory while delegating IDE features to VSCode.
map("n", "<leader>e", call("workbench.files.action.showActiveFileInExplorer"), "Reveal in Explorer")
map("n", "<leader>E", call("workbench.view.explorer"), "Explorer")
map("n", "<leader>ff", call("workbench.action.quickOpen"), "Find Files")
map("n", "<leader>fg", call("workbench.action.findInFiles"), "Find in Files")
map("n", "<leader>fb", call("workbench.action.showAllEditors"), "Find Buffers")
map("n", "<leader>fr", call("workbench.action.openRecent"), "Recent")
map("n", "<leader>gg", call("workbench.view.scm"), "Source Control")

map("n", "<leader>bd", call("workbench.action.closeActiveEditor"), "Close Editor")
map("n", "[b", call("workbench.action.previousEditor"), "Previous Editor")
map("n", "]b", call("workbench.action.nextEditor"), "Next Editor")

map("n", "gd", call("editor.action.revealDefinition"), "Goto Definition")
map("n", "gD", call("editor.action.goToDeclaration"), "Goto Declaration")
map("n", "gI", call("editor.action.goToImplementation"), "Goto Implementation")
map("n", "gy", call("editor.action.goToTypeDefinition"), "Goto Type Definition")
map("n", "gr", call("editor.action.goToReferences"), "References")
map("n", "K", call("editor.action.showHover"), "Hover")

map("n", "<leader>ca", call("editor.action.quickFix"), "Code Action")
map("x", "<leader>ca", call("editor.action.quickFix"), "Code Action")
map("n", "<leader>cr", call("editor.action.rename"), "Rename")
map("n", "<leader>cf", call("editor.action.formatDocument"), "Format Document")
map("x", "<leader>cf", call("editor.action.formatSelection"), "Format Selection")

map("n", "[d", call("editor.action.marker.prev"), "Previous Diagnostic")
map("n", "]d", call("editor.action.marker.next"), "Next Diagnostic")
