return {
  -- Overseer.nvim - Task runner for go test, make, ts-deploy, etc.
  {
    "stevearc/overseer.nvim",
    cmd = { "OverseerRun", "OverseerToggle", "OverseerInfo" },
    opts = {
      templates = { "builtin", "user" },
      strategy = {
        "toggleterm",
        direction = "horizontal",
        autos_croll = true,
        quit_on_exit = "never",
      },
      task_list = {
        direction = "bottom",
        min_height = 25,
        max_height = 25,
        default_detail = 1,
        bindings = {
          ["?"] = "ShowHelp",
          ["g?"] = "ShowHelp",
          ["<CR>"] = "RunAction",
          ["<C-e>"] = "Edit",
          ["o"] = "Open",
          ["<C-v>"] = "OpenVsplit",
          ["<C-s>"] = "OpenSplit",
          ["<C-f>"] = "OpenFloat",
          ["<C-q>"] = "OpenQuickFix",
          ["p"] = "TogglePreview",
          ["<C-l>"] = "IncreaseDetail",
          ["<C-h>"] = "DecreaseDetail",
          ["L"] = "IncreaseAllDetail",
          ["H"] = "DecreaseAllDetail",
          ["["] = "DecreaseWidth",
          ["]"] = "IncreaseWidth",
          ["{"] = "PrevTask",
          ["}"] = "NextTask",
          ["<C-k>"] = "ScrollOutputUp",
          ["<C-j>"] = "ScrollOutputDown",
        },
      },
      -- Custom task templates
      task_list_templates = {
        {
          name = "Go Test",
          builder = function()
            return {
              cmd = { "go", "test" },
              args = { "./..." },
              components = { { "on_output_quickfix", open = true }, "default" },
            }
          end,
          desc = "Run go test ./...",
        },
        {
          name = "Go Test Current Package",
          builder = function()
            local file = vim.fn.expand("%:p:h")
            return {
              cmd = { "go", "test" },
              args = { ".", "-v" },
              cwd = file,
              components = { { "on_output_quickfix", open = true }, "default" },
            }
          end,
          desc = "Run go test in current package",
        },
        {
          name = "Make",
          builder = function()
            return {
              cmd = { "make" },
              components = { { "on_output_quickfix", open = true }, "default" },
            }
          end,
          desc = "Run make",
        },
        {
          name = "ts-deploy",
          builder = function()
            return {
              cmd = { "ts-deploy" },
              components = { { "on_output_quickfix", open = true }, "default" },
            }
          end,
          desc = "Run ts-deploy",
        },
      },
    },
    keys = {
      { "<leader>rr", "<cmd>OverseerRun<cr>", desc = "Run task" },
      { "<leader>rt", "<cmd>OverseerToggle<cr>", desc = "Toggle task list" },
      { "<leader>ra", "<cmd>OverseerQuickAction<cr>", desc = "Task actions" },
      { "<leader>ri", "<cmd>OverseerInfo<cr>", desc = "Task info" },
      { "<leader>rb", "<cmd>OverseerBuild<cr>", desc = "Build task" },
    },
  },
}
