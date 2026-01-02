local M = {}

function M.render_boolean_table(title, tbl)
	local lines = {}

	table.insert(lines, "▸ " .. title)
	table.insert(lines, string.rep("─", 45))
	table.insert(lines, string.format("%-18s %-10s", "NAME", "STATUS"))

	for key, val in pairs(tbl) do
		local status = val and "ON" or "OFF"
		local icon = val and "✓" or " "
		table.insert(lines, string.format("%-18s [%s] %s", key, icon, status))
	end

	table.insert(lines, "")
	return lines
end

function M.render_key_value(title, tbl)
	local lines = {}

	table.insert(lines, "▸ " .. title)
	table.insert(lines, string.rep("─", 45))
	table.insert(lines, string.format("%-18s %-20s", "NAME", "VALUE"))

	for k, v in pairs(tbl) do
		table.insert(lines, string.format("%-18s %s", k, v))
	end

	table.insert(lines, "")
	return lines
end

return M
