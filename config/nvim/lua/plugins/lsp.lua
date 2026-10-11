return {
  {
    "LazyVim/LazyVim",
    opts = {
      plugins = {
        lsp = {
          config = function(_, opts)
            -- ... LazyVim's original config code runs first ...
            -- Patch the problematic mappings require right after the mlsp load
            local have_mason, mlsp = pcall(require, "mason-lspconfig")
            if have_mason then
              -- Fix: Use mlsp.get_mappings() or mlsp.lspconfig_to_package instead of removed module
              local mappings = mlsp.get_mappings and mlsp.get_mappings() or mlsp
              _G.all_mslp_servers = vim.tbl_keys(mappings.lspconfig_to_package or {}) -- store in global to override
            end
          end,
        },
      },
    },
  },
  -- Pin Mason to v1 if the patch above doesn't suffice (safe fallback)
  { "mason-org/mason.nvim", version = "^1.*" },
  { "mason-org/mason-lspconfig.nvim", version = "^1.*" },
}
