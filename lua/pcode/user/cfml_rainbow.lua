local M = {}

local ns = vim.api.nvim_create_namespace("cfml_rainbow")

local brackets = { ["("] = true, [")"] = true, ["["] = true, ["]"] = true, ["{"] = true, ["}"] = true }
local openers = { ["("] = true, ["["] = true, ["{"] = true }

-- Dracula palette
local colors = {
	"#FF79C6", -- pink
	"#BD93F9", -- purple
	"#8BE9FD", -- cyan
	"#50FA7B", -- green
	"#FFB86C", -- orange
	"#F1FA8C", -- yellow
	"#FF5555", -- red
}

local function define_hl()
	for i, fg in ipairs(colors) do
		vim.api.nvim_set_hl(0, "CfmlRainbow" .. i, { fg = fg })
	end
end

function M.refresh(buf)
	buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	local ok, parser = pcall(vim.treesitter.get_parser, buf)
	if not ok or not parser then
		return
	end
	parser:parse(true) -- termasuk lapisan injection (cfscript)

	local list, seen = {}, {}
	parser:for_each_tree(function(tree)
		local function walk(node)
			if not node:named() and brackets[node:type()] then
				local r, c = node:range()
				local key = r .. ":" .. c
				if not seen[key] then
					seen[key] = true
					list[#list + 1] = { r, c, node:type() }
				end
			end
			for child in node:iter_children() do
				walk(child)
			end
		end
		walk(tree:root())
	end)

	table.sort(list, function(a, b)
		if a[1] ~= b[1] then
			return a[1] < b[1]
		end
		return a[2] < b[2]
	end)

	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

	local depth = 0
	for _, b in ipairs(list) do
		local level
		if openers[b[3]] then
			depth = depth + 1
			level = depth
		else
			level = math.max(depth, 1)
			depth = math.max(depth - 1, 0)
		end
		local hl = "CfmlRainbow" .. (((level - 1) % #colors) + 1)
		pcall(vim.api.nvim_buf_set_extmark, buf, ns, b[1], b[2], {
			end_col = b[2] + 1,
			hl_group = hl,
			priority = 250, -- di atas treesitter (100) dan LSP semantic tokens (125)
		})
	end
end

local timers = {}

local function debounced(buf)
	local t = timers[buf]
	if not t then
		t = vim.uv.new_timer()
		timers[buf] = t
	end
	t:stop()
	t:start(
		80,
		0,
		vim.schedule_wrap(function()
			M.refresh(buf)
		end)
	)
end

local function cleanup(buf)
	local t = timers[buf]
	if t then
		t:stop()
		if not t:is_closing() then
			t:close()
		end
		timers[buf] = nil
	end
end

function M.setup(filetypes)
	local group = vim.api.nvim_create_augroup("CfmlRainbow", { clear = true })

	define_hl()
	vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = define_hl })

	vim.api.nvim_create_autocmd("FileType", {
		group = group,
		pattern = filetypes or { "cfml" },
		callback = function(args)
			local buf = args.buf
			M.refresh(buf)

			-- augroup per buffer supaya autocmd tidak menumpuk
			local bgroup = vim.api.nvim_create_augroup("CfmlRainbow_" .. buf, { clear = true })
			vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufEnter" }, {
				group = bgroup,
				buffer = buf,
				callback = function()
					debounced(buf)
				end,
			})
			vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
				group = bgroup,
				buffer = buf,
				callback = function()
					cleanup(buf)
				end,
			})
		end,
	})
end

return M
