local h = require("tests.harness")

h.test("real UI mouse clicks dispatch Lua handlers and redraw after deletion", function()
	local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
	local job = vim.fn.jobstart(
		{ vim.v.progpath, "--embed", "--headless", "-n", "-u", "NONE", "-i", "NONE" },
		{ rpc = true }
	)
	local function request(method, ...)
		return vim.rpcrequest(job, method, ...)
	end
	local function lua(code, args)
		return request("nvim_exec_lua", code, args or {})
	end
	local ok, err = xpcall(function()
		request("nvim_ui_attach", 100, 24, {})
		local ids = lua(
			[[
			vim.opt.runtimepath:prepend(...)
			vim.o.mouse = "a"
			vim.o.hidden = true
			local a = vim.api.nvim_get_current_buf()
			vim.api.nvim_buf_set_name(a, "first.lua")
			local b = vim.api.nvim_create_buf(true, false)
			vim.api.nvim_buf_set_name(b, "second.lua")
			require("tabline").setup({ icons = false })
			vim.cmd.redraw()
			return { a, b }
		]],
			{ root }
		)
		local function click(button, column)
			request("nvim_input_mouse", button, "press", "", 0, 0, column)
			request("nvim_input_mouse", button, "release", "", 0, 0, column)
			lua("vim.cmd.redraw()")
		end
		click("left", 20)
		h.eq(lua("return vim.api.nvim_get_current_buf()"), ids[2])
		lua("vim.bo.modified = true; vim.cmd.redraw()")
		click("middle", 20)
		h.ok(lua("return vim.api.nvim_buf_is_valid(...)", { ids[2] }))
		lua("vim.bo.modified = false; vim.cmd.redraw()")
		click("middle", 20)
		h.ok(not lua("return vim.api.nvim_buf_is_valid(...)", { ids[2] }))
		h.ok(not lua("return require('tabline').render():find('second.lua', 1, true) ~= nil"))
		h.eq(lua("return vim.v.errmsg"), "")
	end, debug.traceback)
	vim.fn.jobstop(job)
	if not ok then
		error(err)
	end
end)
