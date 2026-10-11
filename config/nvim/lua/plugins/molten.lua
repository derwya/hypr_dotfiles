return {
  "benlubas/molten-nvim",
  build = ":UpdateRemotePlugins",
  ft = { "python", "julia", "r", "lua" },
  config = function()
    vim.g.molten_output_win_max_height = 20
    vim.g.molten_virt_text_output = true
  end,
}
