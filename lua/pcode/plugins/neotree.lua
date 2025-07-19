local git_available = vim.fn.executable("git") == 1

return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    {
      "nvim-tree/nvim-web-devicons",
      event = "VeryLazy",
      dependencies = {
        "pojokcodeid/nvim-material-icon",
      },
      config = function()
        require("nvim-web-devicons").setup({
          override = require("nvim-material-icon").get_icons()
        })
      end,
    },
    "MunifTanjim/nui.nvim",
  },

  deactivate = function()
    vim.cmd([[Neotree close]])
  end,

  init = function()
    vim.api.nvim_create_autocmd("BufEnter", {
      group = vim.api.nvim_create_augroup("Neotree_start_directory", { clear = true }),
      desc = "Start Neo-tree with directory",
      once = true,
      callback = function()
        if not package.loaded["neo-tree"] then
          local stats = vim.uv.fs_stat(vim.fn.argv(0))
          if stats and stats.type == "directory" then
            require("neo-tree")
          end
        end
      end,
    })
  end,

  opts = {
    enable_git_status = git_available,
    auto_clean_after_session_restore = true,
    close_if_last_window = true,

    sources = vim.tbl_filter(function(src) return src ~= nil end, {
      "filesystem",
      "buffers",
      git_available and "git_status" or nil,
    }),

    source_selector = {
      winbar = true,
      content_layout = "center",
      sources = {
        { source = "filesystem", display_name = " 󰉓 Files " },
        { source = "buffers", display_name = "  Buffers " },
        { source = "git_status", display_name = "  Git " },
      },
    },

    window = {
      position = "left",
      width = 35,
    },

    default_component_configs = {
      icon = {
        folder_closed = "󰉋",
        folder_open = "󰝰",
        folder_empty = "󰉖",
      },
    },

    filesystem = {
      filtered_items = {
        visible = false,
        hide_dotfiles = false,
        hide_gitignored = false,
        hide_hidden = true,
        hide_by_name = {
          ".git",
          "node_modules",
        },
      },
    },

    buffers = {
      follow_current_file = {
        enabled = true,
        leave_dirs_open = false,
      },
      group_empty_dirs = true,
      show_unloaded = true,
    },

    git_status = {
      symbols = {
        unstaged = "󰄱",
        staged = "󰱒",
      },
    },
  },

  config = function(_, opts)
    require("neo-tree").setup(opts)

    vim.api.nvim_create_autocmd("TermClose", {
      pattern = "*lazygit*",
      callback = function()
        if package.loaded["neo-tree.sources.git_status"] then
          require("neo-tree.sources.git_status").refresh()
        end
      end,
    })

    -- vim.cmd [[
    --   highlight NeoTreeTabActive   guifg=#ffffff guibg=#5f87af
    --   highlight NeoTreeTabInactive guifg=#aaaaaa guibg=NONE
    --   highlight NeoTreeTabSeparatorActive guifg=#5f87af guibg=NONE
    --   highlight NeoTreeTabSeparatorInactive guifg=#3a3a3a guibg=NONE
    -- ]]

  end,
}
