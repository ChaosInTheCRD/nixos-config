-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Smart Splits - Enhanced window navigation and resizing
local map = vim.keymap.set

-- Navigate between splits with Ctrl+hjkl
map("n", "<C-h>", function()
  require("smart-splits").move_cursor_left()
end, { desc = "Move to left split" })
map("n", "<C-j>", function()
  require("smart-splits").move_cursor_down()
end, { desc = "Move to below split" })
map("n", "<C-k>", function()
  require("smart-splits").move_cursor_up()
end, { desc = "Move to above split" })
map("n", "<C-l>", function()
  require("smart-splits").move_cursor_right()
end, { desc = "Move to right split" })

-- Resize splits with Alt+hjkl
map("n", "<M-h>", function()
  require("smart-splits").resize_left()
end, { desc = "Resize split left" })
map("n", "<M-j>", function()
  require("smart-splits").resize_down()
end, { desc = "Resize split down" })
map("n", "<M-k>", function()
  require("smart-splits").resize_up()
end, { desc = "Resize split up" })
map("n", "<M-l>", function()
  require("smart-splits").resize_right()
end, { desc = "Resize split right" })

-- Split management
map("n", "<leader>sv", "<C-w>v", { desc = "Split window vertically" })
map("n", "<leader>sh", "<C-w>s", { desc = "Split window horizontally" })
map("n", "<leader>se", "<C-w>=", { desc = "Make splits equal size" })
map("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close current split" })
