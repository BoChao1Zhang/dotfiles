return {
  {
    "ojroques/nvim-osc52",
    lazy = false,
    opts = {
      max_length = 0,
      silent = true,
      trim = false,
      tmux_passthrough = true,
    },
    config = function(_, opts)
      local osc52 = require("osc52")
      osc52.setup(opts)

      vim.api.nvim_create_autocmd("TextYankPost", {
        desc = "Copy yanks to the local terminal clipboard over SSH",
        callback = function()
          if vim.v.event.operator == "y" and vim.v.event.regname ~= "_" then
            osc52.copy_register(vim.v.event.regname == "" and '"' or vim.v.event.regname)
          end
        end,
      })

      vim.keymap.set("n", "<leader>y", osc52.copy_operator, { expr = true, desc = "OSC52 Copy" })
      vim.keymap.set("n", "<leader>yy", "<leader>y_", { remap = true, desc = "OSC52 Copy Line" })
      vim.keymap.set("x", "<leader>y", osc52.copy_visual, { desc = "OSC52 Copy" })
    end,
  },
}
