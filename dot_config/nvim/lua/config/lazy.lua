local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local sitepath = vim.fn.stdpath("data") .. "/site"
local tool_prefix = vim.env.DOTFILES_TOOL_PREFIX or vim.fn.expand("$HOME/.local/share/dotfiles/toolchain")

local function prepend_path(path)
  if path ~= "" and vim.fn.isdirectory(path) == 1 then
    local parts = vim.split(vim.env.PATH or "", ":", { plain = true })
    if not vim.tbl_contains(parts, path) then
      vim.env.PATH = path .. ":" .. (vim.env.PATH or "")
    end
  end
end

local function repair_runtime_env()
  prepend_path(vim.fn.expand("$HOME/.local/bin"))
  prepend_path(tool_prefix .. "/bin")
  vim.opt.rtp:prepend(sitepath)
end

repair_runtime_env()

if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

vim.api.nvim_create_autocmd("User", {
  pattern = "LazyDone",
  callback = function()
    repair_runtime_env()
    local ok, treesitter_config = pcall(require, "nvim-treesitter.config")
    if ok then
      treesitter_config.setup({ install_dir = sitepath })
    end
  end,
})

require("lazy").setup({
  spec = {
    -- add LazyVim and import its plugins
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    -- import/override with your plugins
    { import = "plugins" },
  },
  defaults = {
    -- By default, only LazyVim plugins will be lazy-loaded. Your custom plugins will load during startup.
    -- If you know what you're doing, you can set this to `true` to have all your custom plugins lazy-loaded by default.
    lazy = false,
    -- It's recommended to leave version=false for now, since a lot the plugin that support versioning,
    -- have outdated releases, which may break your Neovim install.
    version = false, -- always use the latest git commit
    -- version = "*", -- try installing the latest stable version for plugins that support semver
  },
  install = { colorscheme = { "tokyonight", "habamax" } },
  pkg = {
    sources = { "lazy", "packspec" },
  },
  rocks = {
    enabled = false,
    hererocks = false,
  },
  checker = {
    enabled = true, -- check for plugin updates periodically
    notify = false, -- notify on update
  }, -- automatically check for plugin updates
  performance = {
    rtp = {
      paths = {
        vim.fn.stdpath("data") .. "/site",
      },
      -- disable some rtp plugins
      disabled_plugins = {
        "gzip",
        -- "matchit",
        -- "matchparen",
        -- "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})

repair_runtime_env()
