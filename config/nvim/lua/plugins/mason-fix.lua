return {
  "mason-org/mason-lspconfig.nvim",
  config = function(_, opts)
    -- Shim for LazyVim compatibility
    local mappings = require("mason-lspconfig.mappings")
    if not mappings.get_mason_map then
      mappings.get_mason_map = function()
        return require("mason-lspconfig.mappings.server")
      end
    end
    require("mason-lspconfig").setup(opts)
  end,
}
