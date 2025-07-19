return {
  'saghen/blink.cmp',
  event = "InsertEnter",
  dependencies = {
    "rafamadriz/friendly-snippets",
    "mikavilpas/blink-ripgrep.nvim",
    "xzbdmw/colorful-menu.nvim",
    { 'L3MON4D3/LuaSnip', version = 'v2.*' },
  },
  version = '1.*',
  opts = {
    snippets = { preset = 'luasnip' },
    keymap = {
      preset = 'default',
      ['<Up>'] = { 'select_prev', 'fallback' },
      ['<Down>'] = { 'select_next', 'fallback' },
      ['<C-e>'] = false,
      ["<Tab>"] = { 'select_next', 'fallback' },
      ["<S-Tab>"] = { 'select_prev', 'fallback' },
      ['<C-space>'] = {
        function(cmp)
          cmp.show({ providers = { 'lsp', 'path', 'snippets', 'buffer', "ripgrep" } })
        end
      },
    },
    appearance = {
      use_nvim_cmp_as_default = true,
      nerd_font_variant = "mono",
      kind_icons = {
        Array = "",
        Boolean = "󰨙",
        Class = "󰯳",
        Codeium = "󰘦",
        Color = "󰰠",
        Control = "",
        Collapsed = ">",
        Constant = "󰯲",
        Constructor = "",
        Copilot = "",
        Enum = "󰯹",
        EnumMember = "",
        Event = "",
        Field = "",
        File = "",
        Folder = "",
        Function = "󰯼",
        Interface = "󰰅",
        Key = "",
        Keyword = "",
        Method = "󰰑",
        Module = "󰰐",
        Namespace = "󰰔",
        Null = "",
        Number = "󰰔",
        Object = "󰲟",
        Operator = "",
        Package = "󰰚",
        Property = "󰲽",
        Reference = "󰰠",
        Snippet = "󰰢",
        String = "",
        Struct = "󰰣",
        TabNine = "󰏚",
        Text = "󰰥",
        TypeParameter = "󰰦",
        Unit = "󱜥",
        Value = "",
        Variable = "󰰬",
      },
    },
    completion = {
      menu = {
        border = "rounded",
        draw = {
          columns = { { "kind_icon"}, { "label", gap = 0 } },
          components = {
            label = {
              text = require("colorful-menu").blink_components_text,
              highlight = require("colorful-menu").blink_components_highlight,
            },
          },
        }
      },
      documentation = {
        auto_show = true,
        auto_show_delay_ms = 0,
        window = {
          border = "rounded",
        }
      }
    },
    signature = {
      enabled = true,
      window = { border = 'rounded' }
    },
    cmdline = {
      keymap = { preset = 'inherit' },
      completion = { menu = { auto_show = true } },
    },
    sources = {
      default = { 'lsp', 'path', 'snippets', 'buffer', "ripgrep"},
      providers = {
        ripgrep = {
          module = "blink-ripgrep",
          name = "Ripgrep",
          opts = {
            prefix_min_len = 3,
            context_size = 5,
            max_filesize = "1M",
            additional_rg_options = {},
          },
        },
      }
    },
    fuzzy = { implementation = "prefer_rust_with_warning"}
  },
  opts_extend = {
    "sources.default",
    "sources.providers",
  },
  config = function(_, opts)
    require("blink-cmp").setup(opts)
    vim.cmd('highlight link BlinkCmpMenuBorder Normal')
  end
}