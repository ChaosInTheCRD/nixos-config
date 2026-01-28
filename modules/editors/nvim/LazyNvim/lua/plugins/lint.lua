return {
  {
    "mfussenegger/nvim-lint",
    opts = function(_, opts)
      -- Option 1: Disable golangci-lint (recommended - gopls staticcheck is already enabled)
      opts.linters_by_ft = opts.linters_by_ft or {}
      opts.linters_by_ft.go = {} -- Empty means no linters for Go files

      -- Option 2: If you want to keep golangci-lint, ignore exit code 7 (interrupted)
      -- Uncomment this and comment out the above if you prefer:
      -- local golangci_lint = require("lint").linters.golangci_lint
      -- golangci_lint.ignore_exitcode = true
      -- or only ignore code 7:
      -- local original_parser = golangci_lint.parser
      -- golangci_lint.parser = function(output, bufnr, cwd)
      --   -- Suppress "interrupted" errors
      --   if output:match("Request interrupted") then
      --     return {}
      --   end
      --   return original_parser(output, bufnr, cwd)
      -- end

      return opts
    end,
  },

  -- Prevent Mason from auto-installing golangci-lint (use Nix version)
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      -- Remove golangci-lint from ensure_installed if it exists
      opts.ensure_installed = vim.tbl_filter(function(tool)
        return tool ~= "golangci-lint"
      end, opts.ensure_installed)
      return opts
    end,
  },
}
