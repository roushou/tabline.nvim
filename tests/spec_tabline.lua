local h = require("tests.harness")
local tabline = require("tabline")
local render = require("tabline.render").render
local resolve = require("tabline.config").resolve
local prefix = vim.fn.tempname()

local function reset()
	tabline.disable()
	vim.o.hidden = true
	vim.o.tabline = ""
	vim.o.showtabline = 1
	vim.g.actual_curbuf = nil
	local fresh = vim.api.nvim_create_buf(true, false)
	vim.api.nvim_set_current_buf(fresh)
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if buf ~= fresh then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
	end
	vim.bo[fresh].buflisted = false
	return fresh
end

local function buffer(name)
	local buf = vim.api.nvim_create_buf(true, false)
	if name then
		vim.api.nvim_buf_set_name(buf, prefix .. "/" .. name)
	end
	return buf
end

local function evaluate(format)
	return vim.api.nvim_eval_statusline(format, { use_tabline = true, maxwidth = 10000 }).str
end

local function test(name, fn)
	h.test(name, function()
		reset()
		fn()
	end)
end

h.test("require has no editor side effects", function()
	h.eq(vim.o.tabline, "")
	h.eq(vim.fn.exists("#TablineNvim"), 0)
end)

test("empty list renders only fill", function()
	h.eq(evaluate(tabline.render()), "")
	tabline.cycle(1)
end)

test("renders literal percent format syntax without evaluating it", function()
	local buf = buffer("100%{1+1}.lua")
	local text = evaluate(render({ buf }, buf, resolve({ icons = false }), 200))
	h.ok(text:find("100%{1+1}.lua", 1, true))
	h.ok(not text:find("1002.lua", 1, true))
end)

test("control characters in buffer names cannot split the tabline", function()
	local buf = buffer("line\nbreak.lua")
	local text = evaluate(render({ buf }, buf, resolve({ icons = false }), 200))
	h.ok(not text:find("[%c]"))
end)

test("unnamed buffers and modified markers", function()
	local buf = buffer()
	vim.bo[buf].modified = true
	h.ok(evaluate(render({ buf }, buf, resolve({ icons = false }), 200)):find("[No Name] ●", 1, true))
end)

test("duplicate filenames use distinct parent paths", function()
	local a, b, c = buffer("one/src/main.lua"), buffer("two/src/main.lua"), buffer("other.lua")
	local text = evaluate(render({ a, b, c }, a, resolve({ icons = false }), 200))
	h.ok(text:find("one/src/main.lua", 1, true))
	h.ok(text:find("two/src/main.lua", 1, true))
	h.ok(text:find("other.lua", 1, true))
end)

test("multiple unnamed buffers include buffer numbers", function()
	local a, b = buffer(), buffer()
	local text = evaluate(render({ a, b }, a, resolve({ icons = false }), 200))
	h.ok(text:find("[No Name] #" .. a, 1, true))
	h.ok(text:find("[No Name] #" .. b, 1, true))
end)

test("sliding window follows the current buffer at both ends", function()
	local list = {}
	for i = 1, 20 do
		list[i] = buffer("file" .. i)
	end
	local opts = resolve({ icons = false, max_visible = 3 })
	for _, index in ipairs({ 1, 10, 20 }) do
		local format = render(list, list[index], opts, 500)
		local _, count = format:gsub("@v:lua", "")
		h.eq(count, 3)
		h.ok(format:find("%#TablineActive#%" .. list[index] .. "@", 1, true))
	end
end)

test("narrow layouts always retain current buffer and fit display cells", function()
	local list = { buffer("前前前界界界é.lua"), buffer("b.lua"), buffer("c.lua") }
	vim.bo[list[1]].modified = true
	for _, ambiwidth in ipairs({ "single", "double" }) do
		vim.o.ambiwidth = ambiwidth
		for columns = 1, 100 do
			for _, index in ipairs({ 1, 2, 3 }) do
				local format = render(list, list[index], resolve({ icons = false }), columns)
				local text = evaluate(format)
				h.ok(vim.fn.strdisplaywidth(text) <= columns, "exceeded width " .. columns .. ": " .. text)
				h.ok(format:find("%#TablineActive#%" .. list[index] .. "@", 1, true))
			end
		end
	end
	vim.o.ambiwidth = "single"
end)

test("missing icon plugins are optional", function()
	local buf = buffer("plain.lua")
	h.ok(evaluate(render({ buf }, buf, resolve(), 200)):find("plain.lua", 1, true))
end)

test("custom icons are escaped and failing callbacks degrade gracefully", function()
	local buf = buffer("plain.lua")
	local opts = resolve({
		icons = function(id)
			h.eq(id, buf)
			return "%icon"
		end,
	})
	h.ok(evaluate(render({ buf }, buf, opts, 200)):find("%icon plain.lua", 1, true))
	opts.icons = function()
		error("unavailable")
	end
	h.ok(evaluate(render({ buf }, buf, opts, 200)):find("plain.lua", 1, true))
end)

test("icon providers loaded after setup are detected", function()
	local buf = buffer("icon.lua")
	tabline.setup()
	package.loaded["mini.icons"] = {
		get = function()
			return "MINI"
		end,
	}
	local text = evaluate(tabline.render())
	package.loaded["mini.icons"] = nil
	h.ok(text:find("MINI icon.lua", 1, true))
	package.loaded["nvim-web-devicons"] = {
		get_icon = function()
			return "DEV"
		end,
	}
	text = evaluate(render({ buf }, buf, resolve(), 200))
	package.loaded["nvim-web-devicons"] = nil
	h.ok(text:find("DEV icon.lua", 1, true))
end)

test("cycle wraps and skips unlisted buffers", function()
	local a, hidden, b = buffer("a"), buffer("hidden"), buffer("b")
	vim.bo[hidden].buflisted = false
	vim.api.nvim_set_current_buf(a)
	tabline.cycle(1)
	h.eq(vim.api.nvim_get_current_buf(), b)
	tabline.cycle(1)
	h.eq(vim.api.nvim_get_current_buf(), a)
	tabline.cycle(-1)
	h.eq(vim.api.nvim_get_current_buf(), b)
	tabline.cycle(0)
	h.eq(vim.api.nvim_get_current_buf(), b)
	tabline.cycle(2)
	h.eq(vim.api.nvim_get_current_buf(), b)
end)

test("cycle from an unlisted buffer chooses the appropriate end", function()
	local scratch = vim.api.nvim_get_current_buf()
	local a, b = buffer("a"), buffer("b")
	tabline.cycle(1)
	h.eq(vim.api.nvim_get_current_buf(), a)
	vim.api.nvim_set_current_buf(scratch)
	tabline.cycle(-1)
	h.eq(vim.api.nvim_get_current_buf(), b)
end)

test("current selection ignores stale actual_curbuf", function()
	local a, b = buffer("a"), buffer("b")
	vim.api.nvim_set_current_buf(a)
	vim.g.actual_curbuf = tostring(b)
	h.ok(tabline.render():find("%#TablineActive#%" .. a .. "@", 1, true))
end)

test("left click selects and middle click deletes unmodified buffers", function()
	local a, b = buffer("a"), buffer("b")
	tabline.click(a, 1, "l")
	h.eq(vim.api.nvim_get_current_buf(), a)
	tabline.click(b, 1, "m")
	h.ok(not vim.api.nvim_buf_is_valid(b))
end)

test("modified buffers survive middle clicks", function()
	local buf = buffer("modified")
	vim.bo[buf].modified = true
	local old, message = vim.notify, nil
	vim.notify = function(text)
		message = text
	end
	tabline.click(buf, 1, "m")
	vim.notify = old
	h.ok(vim.api.nvim_buf_is_valid(buf))
	h.ok(message:find("modified", 1, true))
end)

test("unsupported buttons, stale and unlisted click targets are ignored", function()
	local before = vim.api.nvim_get_current_buf()
	local buf = buffer("target")
	tabline.click(buf, 1, "r")
	h.eq(vim.api.nvim_get_current_buf(), before)
	vim.bo[buf].buflisted = false
	tabline.click(buf, 1, "l")
	h.eq(vim.api.nvim_get_current_buf(), before)
	vim.api.nvim_buf_delete(buf, { force = true })
	tabline.click(buf, 1, "l")
end)

test("switch failures notify without escaping through callbacks", function()
	local a, b = buffer("a"), buffer("b")
	vim.api.nvim_set_current_buf(a)
	vim.bo[a].modified = true
	vim.o.hidden = false
	local old, messages = vim.notify, {}
	vim.notify = function(text)
		messages[#messages + 1] = text
	end
	tabline.click(b, 1, "l")
	tabline.cycle(1)
	vim.notify = old
	h.eq(#messages, 2)
	h.eq(vim.api.nvim_get_current_buf(), a)
end)

test("setup is idempotent and disable restores owned options", function()
	vim.o.tabline = "previous"
	vim.o.mouse = ""
	local maps = vim.api.nvim_get_keymap("n")
	tabline.setup({ icons = false })
	local count = #vim.api.nvim_get_autocmds({ group = "TablineNvim" })
	tabline.setup({ padding = 1 })
	h.eq(#vim.api.nvim_get_autocmds({ group = "TablineNvim" }), count)
	h.eq(vim.o.showtabline, 2)
	h.eq(vim.o.mouse, "")
	h.eq(vim.api.nvim_get_keymap("n"), maps)
	tabline.disable()
	h.eq(vim.o.tabline, "previous")
	h.eq(vim.o.showtabline, 1)
	h.eq(vim.fn.exists("#TablineNvim"), 0)
	tabline.disable()
end)

test("disable respects options changed by other plugins", function()
	tabline.setup()
	vim.o.tabline = "replacement"
	vim.o.showtabline = 0
	tabline.disable()
	h.eq(vim.o.tabline, "replacement")
	h.eq(vim.o.showtabline, 0)
end)

test("showtabline false leaves visibility alone across reconfiguration", function()
	vim.o.showtabline = 0
	tabline.setup()
	tabline.setup({ showtabline = false })
	h.eq(vim.o.showtabline, 0)
end)

test("invalid setup leaves the active configuration intact", function()
	tabline.setup()
	local expr = vim.o.tabline
	for _, opts in ipairs({
		{ max_visible = 0 },
		{ padding = -1 },
		{ icons = "yes" },
		{ showtabline = 3 },
		{ modified = "\n" },
		{ typo = true },
		{ max_name_length = math.huge },
		{ padding = 0 / 0 },
		false,
	}) do
		h.ok(not pcall(tabline.setup, opts))
		h.eq(vim.o.tabline, expr)
	end
end)

test("invalid cycle directions fail clearly", function()
	for _, direction in ipairs({ "1", 1.5, math.huge, 0 / 0 }) do
		h.ok(not pcall(tabline.cycle, direction))
	end
end)

test("highlights resolve links and preserve explicit overrides", function()
	vim.cmd("highlight clear TablineActive")
	vim.cmd("highlight clear TablineActiveTail")
	vim.api.nvim_set_hl(0, "TablineTestAccent", { fg = 0x123456 })
	vim.api.nvim_set_hl(0, "Directory", { link = "TablineTestAccent" })
	tabline.setup()
	h.eq(vim.api.nvim_get_hl(0, { name = "TablineActive" }).bg, 0x123456)
	vim.api.nvim_set_hl(0, "TablineTestAccent", { fg = 0x345678 })
	vim.api.nvim_exec_autocmds("ColorScheme", { pattern = "test" })
	h.eq(vim.api.nvim_get_hl(0, { name = "TablineActive" }).bg, 0x345678)
	vim.api.nvim_set_hl(0, "TablineActive", { fg = 0xABCDEF })
	vim.api.nvim_exec_autocmds("ColorScheme", { pattern = "test" })
	h.eq(vim.api.nvim_get_hl(0, { name = "TablineActive" }).fg, 0xABCDEF)
	vim.cmd("highlight clear TablineActive")
	vim.api.nvim_set_hl(0, "TablineTestAccent", { fg = 0x654321 })
	vim.api.nvim_exec_autocmds("ColorScheme", { pattern = "test" })
	h.eq(vim.api.nvim_get_hl(0, { name = "TablineActive" }).bg, 0x654321)
end)

test("installed expression evaluates through Neovim", function()
	local buf = buffer("native%test.lua")
	vim.api.nvim_set_current_buf(buf)
	tabline.setup({ icons = false })
	h.ok(evaluate(vim.o.tabline):find("native%test.lua", 1, true))
	h.eq(vim.v.errmsg, "")
end)

test("queued redraws are harmless after disable and setup", function()
	tabline.setup()
	buffer("queued")
	tabline.disable()
	tabline.setup()
	vim.wait(20)
	h.ok(evaluate(vim.o.tabline):find("queued", 1, true))
end)
