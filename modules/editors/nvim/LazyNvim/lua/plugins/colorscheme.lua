return {
  -- Catppuccin with custom Synthwave theme to match sketchybar
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    opts = {
      flavour = "macchiato", -- base flavor
      transparent_background = false,
      show_end_of_buffer = false,
      term_colors = true,
      dim_inactive = {
        enabled = false,
        shade = "dark",
        percentage = 0.15,
      },
      no_italic = false,
      no_bold = false,
      no_underline = false,
      styles = {
        comments = { "italic" },
        conditionals = { "italic" },
        loops = {},
        functions = {},
        keywords = {},
        strings = {},
        variables = {},
        numbers = {},
        booleans = {},
        properties = {},
        types = {},
        operators = {},
      },
      -- Custom color overrides to match sketchybar Synthwave theme
      color_overrides = {
        macchiato = {
          -- Base colors matching sketchybar
          base = "#261837",     -- NAVY (main background)
          mantle = "#261837",   -- NAVY (darker areas)
          crust = "#150B24",    -- Even darker for depth

          -- Text colors (brightened for better contrast)
          text = "#E0EBED",     -- Much lighter SAGE (main text)
          subtext1 = "#C8D5D8", -- lighter SAGE
          subtext0 = "#B5C4C7", -- medium SAGE

          -- Overlay colors (brightened for better contrast)
          overlay2 = "#7B6BA8", -- Brighter purple for comments/punctuation
          overlay1 = "#5A4988", -- Medium purple variant
          overlay0 = "#483870", -- Darker purple variant
          surface2 = "#291849", -- purple variant
          surface1 = "#261837", -- NAVY
          surface0 = "#150B24", -- darker

          -- Accent colors from sketchybar
          rosewater = "#E98074", -- LAVENDER
          flamingo = "#F0A89E",  -- lighter LAVENDER
          pink = "#D83F87",      -- PINK
          mauve = "#D83F87",     -- PINK
          red = "#E98074",       -- LAVENDER
          maroon = "#D83F87",    -- PINK
          peach = "#F0A89E",     -- lighter LAVENDER
          yellow = "#E98074",    -- LAVENDER
          green = "#C5D7DA",     -- Brighter SAGE for better readability
          teal = "#C5D7DA",      -- Brighter SAGE
          sky = "#7BB8C8",       -- muted cyan for visibility
          sapphire = "#7BB8C8",  -- muted cyan
          blue = "#7BB8C8",      -- muted cyan
          lavender = "#7BB8C8",  -- muted cyan
        },
      },
      custom_highlights = function(colors)
        -- Slightly lighter/faded version of the main purple background for NeoTree
        local neotree_bg = "#2e203f"

        return {
          -- Treesitter highlights for better visibility
          ["@variable"] = { fg = colors.text },
          ["@variable.builtin"] = { fg = colors.pink },
          ["@variable.parameter"] = { fg = colors.flamingo },
          ["@variable.member"] = { fg = colors.sky },
          ["@function"] = { fg = colors.blue },
          ["@function.builtin"] = { fg = colors.sapphire },
          ["@function.method"] = { fg = colors.blue },
          ["@keyword"] = { fg = colors.mauve },
          ["@keyword.function"] = { fg = colors.mauve },
          ["@keyword.operator"] = { fg = colors.mauve },
          ["@keyword.return"] = { fg = colors.pink },
          ["@string"] = { fg = colors.green },
          ["@number"] = { fg = colors.peach },
          ["@boolean"] = { fg = colors.peach },
          ["@type"] = { fg = colors.yellow },
          ["@type.builtin"] = { fg = colors.yellow },
          ["@property"] = { fg = colors.sky },
          ["@constructor"] = { fg = colors.sapphire },
          ["@operator"] = { fg = colors.sky },
          ["@punctuation.bracket"] = { fg = colors.overlay2 },
          ["@punctuation.delimiter"] = { fg = colors.overlay2 },
          ["@comment"] = { fg = colors.overlay2, style = { "italic" } },
          Comment = { fg = colors.overlay2, style = { "italic" } },

          -- Line numbers
          LineNr = { fg = colors.overlay1 },
          CursorLineNr = { fg = colors.mauve, style = { "bold" } },

          -- Visual selection (matching Ghostty's selection color #3D2C7F)
          Visual = { bg = colors.overlay2, style = { "bold" } },
          VisualNOS = { bg = colors.overlay1 },

          -- NeoTree/File explorer highlights with subtle two-tone background
          NeoTreeNormal = { fg = colors.text, bg = neotree_bg },
          NeoTreeNormalNC = { fg = colors.text, bg = neotree_bg },
          NeoTreeEndOfBuffer = { bg = neotree_bg },
          -- Enhanced separator for 3D depth effect
          NeoTreeWinSeparator = { fg = colors.mauve, bg = neotree_bg, style = { "bold" } },
          NeoTreeVertSplit = { fg = colors.mauve, bg = neotree_bg },
          NeoTreeDirectoryIcon = { fg = colors.blue },
          NeoTreeDirectoryName = { fg = colors.blue },
          NeoTreeFileName = { fg = colors.text },
          NeoTreeFileIcon = { fg = colors.overlay2 },
          NeoTreeRootName = { fg = colors.pink, style = { "bold" } },
          NeoTreeIndentMarker = { fg = colors.overlay0 },
          NeoTreeGitAdded = { fg = colors.green },
          NeoTreeGitDeleted = { fg = colors.red },
          NeoTreeGitModified = { fg = colors.yellow },
          NeoTreeGitUntracked = { fg = colors.flamingo },

          -- Split/window borders
          WinSeparator = { fg = colors.overlay2, bg = colors.base },
          VertSplit = { fg = colors.overlay2, bg = colors.base },
        }
      end,
      integrations = {
        cmp = true,
        gitsigns = true,
        nvimtree = true,
        treesitter = true,
        notify = true,
        mini = {
          enabled = true,
          indentscope_color = "",
        },
        neotree = true,
        native_lsp = {
          enabled = true,
          virtual_text = {
            errors = { "italic" },
            hints = { "italic" },
            warnings = { "italic" },
            information = { "italic" },
          },
          underlines = {
            errors = { "underline" },
            hints = { "underline" },
            warnings = { "underline" },
            information = { "underline" },
          },
          inlay_hints = {
            background = true,
          },
        },
        telescope = {
          enabled = true,
        },
        which_key = true,
        mason = true,
        neotree = true,
        noice = true,
        lsp_trouble = true,
        neotest = true,
        dashboard = true,
        snacks = true,
      },
    },
  },

  -- Configure LazyVim to load catppuccin
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin-macchiato",
    },
  },
}
