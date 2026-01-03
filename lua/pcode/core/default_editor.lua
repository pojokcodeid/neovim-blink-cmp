local M = {}

local path = vim.fn.stdpath("config") .. "/lua/pcode/user/default.lua"

local function read()
	return vim.fn.readfile(path)
end

local function write(lines)
	vim.fn.writefile(lines, path)
end

-- edit value key di dalam table tertentu
-- example: set_table_value("pcode.extras", "rest", true)
function M.set_table_value(table_name, key, value)
	local lines = read()
	local in_table = false
	local changed = false
	local value_str = tostring(value)

	for i, line in ipairs(lines) do
		if line:match("^%s*" .. table_name:gsub("%.", "%%.") .. "%s*=%s*{") then
			in_table = true
		end

		if in_table and line:match("^%s*}") then
			in_table = false
		end

		if in_table and line:match(key .. "%s*=") then
			lines[i] = line:gsub(key .. "%s*=%s*[^,}]+", key .. " = " .. value_str)
			changed = true
		end
	end

	if changed then
		write(lines)
	end

	return changed
end

function M.set_dot_value(full_key, value)
	local lines = read()
	local changed = false
	local value_str = tostring(value)

	for i, line in ipairs(lines) do
		-- escape dot untuk pattern lua
		local key_pattern = full_key:gsub("%.", "%%.")

		-- match:
		-- pcode.transparent=false
		-- pcode.transparent = false
		local pattern = key_pattern .. "%s*=%s*[^,%s}]+"

		if line:match(pattern) then
			lines[i] = line:gsub(pattern, full_key .. "=" .. value_str)
			changed = true
		end
	end

	if changed then
		write(lines)
	end

	return changed
end

function M.toggle_table_value(table_name, key)
	local lines = read()
	local in_table = false
	local new_state = nil

	for i, line in ipairs(lines) do
		if line:match("^%s*" .. table_name:gsub("%.", "%%.") .. "%s*=%s*{") then
			in_table = true
		end

		if in_table and line:match("^%s*}") then
			in_table = false
		end

		if in_table and line:match(key .. "%s*=%s*true") then
			lines[i] = line:gsub(key .. "%s*=%s*true", key .. " = false")
			new_state = false
			break
		end

		if in_table and line:match(key .. "%s*=%s*false") then
			lines[i] = line:gsub(key .. "%s*=%s*false", key .. " = true")
			new_state = true
			break
		end
	end

	if new_state ~= nil then
		write(lines)
	end

	return new_state
end

function M.replace_theme(theme_key, theme_value)
	local lines = vim.fn.readfile(path)
	local out = {}
	local in_block = false
	local replaced = false

	for _, line in ipairs(lines) do
		if line:match("^%s*pcode%.themes%s*=%s*{") then
			table.insert(out, "pcode.themes = {")
			table.insert(out, string.format('  %s = "%s"', theme_key, theme_value))
			table.insert(out, "}")
			in_block = true
			replaced = true
		elseif in_block then
			if line:match("^%s*}") then
				in_block = false
			end
		-- skip old content
		else
			table.insert(out, line)
		end
	end

	if replaced then
		vim.fn.writefile(out, path)
	end

	return replaced
end
return M
