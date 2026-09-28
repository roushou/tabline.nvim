local M = {}

---@class tabline.Config
---@field max_visible? integer Maximum number of buffer labels.
---@field max_name_length? integer Maximum filename width in display cells.
---@field padding? integer Spaces on each side of a label.
---@field icons? boolean|fun(bufnr: integer): string? Optional plain-text icon provider.
---@field modified? string Modified-buffer marker, including its leading space.
---@field separator? string Tail of the active buffer label.
---@field overflow? string Hidden-buffer indicator.
---@field showtabline? integer|false Set 'showtabline', or leave it alone.

M.defaults = {
	max_visible = 15,
	max_name_length = 32,
	padding = 2,
	icons = true,
	modified = " ●",
	separator = "▍",
	overflow = "…",
	showtabline = 2,
}

local function integer(value, min, max)
	return type(value) == "number" and value == math.floor(value) and value >= min and value <= max
end

function M.resolve(opts)
	if opts ~= nil and type(opts) ~= "table" then
		error("tabline.nvim: setup expects a table", 3)
	end
	local config = vim.deepcopy(M.defaults)
	for key, value in pairs(opts or {}) do
		if M.defaults[key] == nil then
			error("tabline.nvim: unknown option: " .. tostring(key), 3)
		end
		config[key] = value
	end
	for _, key in ipairs({ "max_visible", "max_name_length", "padding" }) do
		if not integer(config[key], key == "padding" and 0 or 1, 10000) then
			error(
				"tabline.nvim: "
					.. key
					.. " must be an integer between "
					.. (key == "padding" and 0 or 1)
					.. " and 10000",
				3
			)
		end
	end
	if type(config.icons) ~= "boolean" and type(config.icons) ~= "function" then
		error("tabline.nvim: icons must be a boolean or function", 3)
	end
	for _, key in ipairs({ "modified", "separator", "overflow" }) do
		if type(config[key]) ~= "string" or config[key]:find("[%c]") then
			error("tabline.nvim: " .. key .. " must be a single-line string without control characters", 3)
		end
	end
	if config.showtabline ~= false and not integer(config.showtabline, 0, 2) then
		error("tabline.nvim: showtabline must be false, 0, 1, or 2", 3)
	end
	return config
end

return M
