local function extend_unique(list, values)
  local seen = {}
  for _, value in ipairs(list) do
    seen[value] = true
  end
  for _, value in ipairs(values) do
    if not seen[value] then
      table.insert(list, value)
      seen[value] = true
    end
  end
end

return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.install_dir = vim.fn.stdpath("data") .. "/site"
    end,
  },
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      extend_unique(opts.ensure_installed, {
        "codelldb",
        "debugpy",
        "rust-analyzer",
        "tree-sitter-cli",
        "typstyle",
      })
    end,
  },
}
