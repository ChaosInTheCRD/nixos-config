return {
  -- Smart split navigation with tmux/terminal multiplexer support
  {
    "mrjones2014/smart-splits.nvim",
    lazy = false,
    opts = {
      ignored_filetypes = { "nofile", "quickfix", "qf", "prompt" },
      ignored_buftypes = { "nofile" },
    },
  },

  -- Visual window picker for neo-tree and other plugins
  {
    "s1n7ax/nvim-window-picker",
    name = "window-picker",
    event = "VeryLazy",
    version = "2.*",
    opts = {
      hint = "floating-big-letter",
      show_prompt = false,
      filter_rules = {
        include_current_win = false,
        autoselect_one = true,
        bo = {
          filetype = { "neo-tree", "neo-tree-popup", "notify" },
          buftype = { "terminal", "quickfix" },
        },
      },
    },
  },

  -- Integrate window-picker with neo-tree
  {
    "nvim-neo-tree/neo-tree.nvim",
    optional = true,
    opts = {
      window = {
        position = "left",
        width = 35,
        mappings = {
          ["w"] = "open_with_window_picker",
          ["s"] = "split_with_window_picker",
          ["v"] = "vsplit_with_window_picker",
        },
      },
      -- Add visual depth with separator styling
      use_popups_for_input = false,
      enable_diagnostics = true,
      enable_git_status = true,
    },
  },
}
