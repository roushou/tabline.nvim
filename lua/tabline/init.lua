--- A buffer tabline for Neovim 0.10+. Requiring this module has no side effects.
local M = {}
local config = require("tabline.config").resolve()
local expression = "%!v:lua.require'tabline'.render()"
local group, previous, installed_showtabline
local generation, pending = 0, false
local highlights = {}

local function buffers()
	return vim.tbl_filter(function(buf)
		return vim.bo[buf].buflisted
	end, vim.api.nvim_list_bufs())
end

local function notify(message)
	vim.notify(message, vim.log.levels.WARN, { title = "tabline.nvim" })
end

local function apply_highlights()
	local function define(name, spec)
		local current = vim.api.nvim_get_hl(0, { name = name, link = true, create = false })
		-- Refresh our own colors, but preserve highlights supplied by the user.
		spec.default = not vim.deep_equal(current, highlights[name])
		vim.api.nvim_set_hl(0, name, spec)
		if not spec.default or next(current) == nil then
			highlights[name] = vim.api.nvim_get_hl(0, { name = name, link = true })
		end
	end
	local function color(groups, field, fallback)
		for _, name in ipairs(groups) do
			local hl = vim.api.nvim_get_hl(0, { name = name, link = false, create = false })
			if hl[field] then
				return hl[field]
			end
		end
		return fallback
	end
	local bg = color({ "StatusLine", "Normal" }, "bg", 0x16161D)
	local accent = color({ "Directory", "Function" }, "fg", 0x7E9CD8)
	define("TablineActive", { fg = bg, bg = accent, bold = true })
	define("TablineActiveTail", { fg = accent })
	define("TablineOverflow", { link = "Comment" })
end

local function redraw()
	if pending then
		return
	end
	pending = true
	local token = generation
	-- BufDelete/BufWipeout fire before the list changes; render on the next tick.
	vim.schedule(function()
		if token ~= generation then
			return
		end
		pending = false
		if group and vim.o.tabline == expression then
			vim.cmd.redrawtabline()
		end
	end)
end

--- Return a native tabline format string. Safe to call before setup().
---@return string
function M.render()
	return require("tabline.render").render(buffers(), vim.api.nvim_get_current_buf(), config, vim.o.columns)
end

--- Switch or close a clicked buffer. Never force-delete modified buffers.
---@param bufnr integer
---@param clicks integer
---@param button string
---@param modifiers? string
function M.click(bufnr, clicks, button, modifiers)
	if not vim.api.nvim_buf_is_valid(bufnr) or not vim.bo[bufnr].buflisted then
		return
	end
	local ok, err
	if button == "l" then
		ok, err = pcall(vim.api.nvim_set_current_buf, bufnr)
	elseif button == "m" then
		if vim.bo[bufnr].modified then
			notify("Buffer modified; write it before closing")
			return
		end
		ok, err = pcall(vim.api.nvim_buf_delete, bufnr, { force = false })
	else
		return
	end
	if not ok then
		notify(tostring(err))
	end
end

--- Cycle through listed buffers in buffer-number order, wrapping at either end.
---@param direction integer Positive moves forward, negative moves backward.
function M.cycle(direction)
	if type(direction) ~= "number" or direction ~= math.floor(direction) or math.abs(direction) == math.huge then
		error("tabline.nvim: direction must be a finite integer", 2)
	end
	if direction == 0 then
		return
	end
	local listed = buffers()
	if #listed == 0 then
		return
	end
	local current, index = vim.api.nvim_get_current_buf(), nil
	for i, buf in ipairs(listed) do
		if buf == current then
			index = i
			break
		end
	end
	local next_index = index and ((index - 1 + direction) % #listed + 1) or (direction > 0 and 1 or #listed)
	local ok, err = pcall(vim.api.nvim_set_current_buf, listed[next_index])
	if not ok then
		notify(tostring(err))
	end
end

--- Stop redraws and restore options still owned by tabline.nvim.
function M.disable()
	generation = generation + 1
	pending = false
	if group then
		vim.api.nvim_del_augroup_by_id(group)
		group = nil
	end
	if previous then
		if vim.o.tabline == expression then
			vim.o.tabline = previous.tabline
		end
		if installed_showtabline ~= nil and vim.o.showtabline == installed_showtabline then
			vim.o.showtabline = previous.showtabline
		end
	end
	previous, installed_showtabline = nil, nil
end

--- Configure and enable the tabline. Each call merges opts over fresh defaults.
---@param opts? tabline.Config
function M.setup(opts)
	if vim.fn.has("nvim-0.10") ~= 1 then
		error("tabline.nvim requires Neovim 0.10 or newer", 2)
	end
	-- Validate first: a typo must not tear down a working tabline.
	local resolved = require("tabline.config").resolve(opts)
	M.disable()
	config = resolved
	previous = { tabline = vim.o.tabline, showtabline = vim.o.showtabline }
	group = vim.api.nvim_create_augroup("TablineNvim", { clear = true })
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = group,
		callback = function()
			apply_highlights()
			redraw()
		end,
		desc = "Restore tabline highlight defaults",
	})
	vim.api.nvim_create_autocmd({
		"BufAdd",
		"BufDelete",
		"BufEnter",
		"BufWipeout",
		"BufFilePost",
		"BufModifiedSet",
		"FileType",
		"VimResized",
		"TabEnter",
		"WinEnter",
	}, { group = group, callback = redraw, desc = "Refresh buffer tabline" })
	vim.api.nvim_create_autocmd("OptionSet", {
		group = group,
		pattern = { "buflisted", "modified", "ambiwidth" },
		callback = redraw,
		desc = "Refresh buffer tabline options",
	})
	apply_highlights()
	if config.showtabline ~= false then
		vim.o.showtabline = config.showtabline
		installed_showtabline = config.showtabline
	end
	vim.o.tabline = expression
	redraw()
end

return M
