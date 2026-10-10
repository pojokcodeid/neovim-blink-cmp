_G.pcode = _G.pcode or {}
require("pcode.user.default")
require("pcode.config.lazy_config")
require("pcode.user.colorscheme")
require("pcode.user.ts_queries").setup()
require("pcode.user.compare")
require("pcode.user.bgrun").setup()
require("pcode.user.cfml_rainbow").setup({ "cfml" })
