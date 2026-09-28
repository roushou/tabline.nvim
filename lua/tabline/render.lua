local M = {}
local width = vim.fn.strdisplaywidth

local function escape(text)
	return (vim.fn.strtrans(text):gsub("%%", "%%%%"))
end

-- Clip in display cells, never bytes (wide and combining characters are valid).
local function clip(text, limit)
	if width(text) <= limit then
		return text
	end
	if limit <= 0 then
		return ""
	end
	local ellipsis = width("…") <= limit and "…" or "."
	local result = ""
	for i = 0, vim.fn.strchars(text) - 1 do
		local next_text = result .. vim.fn.strcharpart(text, i, 1)
		if width(next_text .. ellipsis) > limit then
			break
		end
		result = next_text
	end
	return result .. ellipsis
end

local function icon_provider(config)
	if type(config.icons) == "function" then
		return config.icons
	end
	if not config.icons then
		return function() end
	end
	-- Only probe once per render; providers loaded after setup are supported.
	local ok, mini = pcall(require, "mini.icons")
	if ok then
		return function(buf)
			local path = vim.api.nvim_buf_get_name(buf)
			if path ~= "" then
				return mini.get("file", path)
			end
		end
	end
	local found, devicons = pcall(require, "nvim-web-devicons")
	return function(buf)
		local path = vim.api.nvim_buf_get_name(buf)
		if found and path ~= "" then
			return devicons.get_icon(vim.fn.fnamemodify(path, ":t"), nil, { default = true })
		end
	end
end

-- Distinguish duplicate basenames with the shortest unique path suffix.
local function names(buffers)
	local paths, labels, counts = {}, {}, {}
	for i, buf in ipairs(buffers) do
		local path = vim.api.nvim_buf_get_name(buf)
		paths[i] = path
		labels[i] = path ~= "" and vim.fn.fnamemodify(path, ":t") or "[No Name]"
		counts[labels[i]] = (counts[labels[i]] or 0) + 1
	end
	for i, label in ipairs(labels) do
		if counts[label] > 1 then
			if paths[i] == "" then
				labels[i] = label .. " #" .. buffers[i]
			else
				local suffix = label
				local parent = vim.fn.fnamemodify(paths[i], ":h")
				while parent ~= "." and parent ~= "/" do
					suffix = vim.fn.fnamemodify(parent, ":t") .. "/" .. suffix
					local unique = true
					for j, path in ipairs(paths) do
						if i ~= j and path:sub(-#suffix - 1) == "/" .. suffix then
							unique = false
							break
						end
					end
					if unique then
						break
					end
					local next_parent = vim.fn.fnamemodify(parent, ":h")
					if next_parent == parent then
						break
					end
					parent = next_parent
				end
				labels[i] = suffix
			end
		end
	end
	return labels
end

function M.render(buffers, current, config, columns)
	if #buffers == 0 then
		return "%#TabLineFill#"
	end
	local labels, segments = names(buffers), {}
	local provider = icon_provider(config)
	local selected = 1
	for i, buf in ipairs(buffers) do
		if buf == current then
			selected = i
		end
	end

	local function make_segment(i, limit)
		local buf = buffers[i]
		local active = buf == current
		local ok, icon = pcall(provider, buf)
		icon = ok and type(icon) == "string" and icon ~= "" and vim.fn.strtrans(icon) .. " " or ""
		local marker = vim.bo[buf].modified and config.modified or ""
		local tail = active and config.separator or ""
		local pad = (" "):rep(config.padding)
		local label = clip(vim.fn.strtrans(labels[i]), config.max_name_length)
		local text = pad .. icon .. label .. marker .. pad
		if limit and width(text .. tail .. " ") > limit then
			-- On narrow screens prioritize the filename and modified marker.
			tail = ""
			marker = clip(marker, math.max(0, limit - 1))
			text = clip(label, math.max(0, limit - width(marker))) .. marker
		else
			tail = tail .. " "
		end
		local group = active and "TablineActive" or "TabLine"
		local format = "%#" .. group .. "#%" .. buf .. "@v:lua.require'tabline'.click@" .. escape(text) .. "%X"
		if active then
			format = format .. "%#TablineActiveTail#" .. escape(tail)
		else
			format = format .. "%#TabLineFill#" .. escape(tail)
		end
		return { format = format .. "%#TabLineFill#", width = width(text .. tail) }
	end

	local first = math.max(1, selected - math.floor(config.max_visible / 2))
	local last = math.min(#buffers, first + config.max_visible - 1)
	first = math.max(1, last - config.max_visible + 1)
	local total = 0
	for i = first, last do
		segments[i] = make_segment(i)
		total = total + segments[i].width
	end
	local overflow = config.overflow ~= "" and config.overflow .. " " or ""
	local function extra()
		return (first > 1 and width(overflow) or 0) + (last < #buffers and width(overflow) or 0)
	end
	while first < last and total + extra() > columns do
		if selected - first >= last - selected then
			total = total - segments[first].width
			first = first + 1
		else
			total = total - segments[last].width
			last = last - 1
		end
	end
	if total + extra() > columns then
		-- At least one cell remains for the selected label.
		if extra() >= columns then
			overflow = ""
		end
		segments[first] = make_segment(first, math.max(1, columns - extra()))
	end
	local parts = { "%#TabLineFill#" }
	local indicator = "%#TablineOverflow#" .. escape(overflow) .. "%#TabLineFill#"
	if first > 1 then
		parts[#parts + 1] = indicator
	end
	for i = first, last do
		parts[#parts + 1] = segments[i].format
	end
	if last < #buffers then
		parts[#parts + 1] = indicator
	end
	return table.concat(parts)
end

return M
