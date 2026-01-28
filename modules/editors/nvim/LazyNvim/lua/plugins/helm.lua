return {
  -- Enhanced Helm support with language server
  {
    "towolf/vim-helm",
    ft = "helm",
  },

  -- Configure helm-ls (Language Server for Helm)
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        helm_ls = {
          settings = {
            ["helm-ls"] = {
              yamlls = {
                enabled = true,
                diagnosticsLimit = 50,
                showDiagnosticsDirectly = false,
                path = "yaml-language-server",
                config = {
                  schemas = {
                    kubernetes = "templates/**",
                  },
                  completion = true,
                  hover = true,
                },
              },
            },
          },
        },
      },
    },
  },

  -- Ensure proper filetype detection for Helm templates
  {
    "neovim/nvim-lspconfig",
    init = function()
      vim.filetype.add({
        extension = {
          gotmpl = "helm",
        },
        pattern = {
          [".*/templates/.*%.yaml"] = "helm",
          [".*/templates/.*%.tpl"] = "helm",
        },
      })
    end,
  },
}
