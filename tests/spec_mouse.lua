local h = require("tests.harness")

h.test("real UI edits, writes, and mouse clicks update the tabline", function()
	local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
	local directory = vim.fn.tempname()
	vim.fn.mkdir(directory, "p")
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
			local root, directory = ...
			vim.opt.runtimepath:prepend(root)
			vim.o.mouse = "a"
			vim.o.hidden = true
			local a = vim.api.nvim_get_current_buf()
			vim.api.nvim_buf_set_name(a, directory .. "/first.lua")
			local b = vim.api.nvim_create_buf(true, false)
			vim.api.nvim_buf_set_name(b, directory .. "/second.lua")
			require("tabline").setup({ icons = false })
			vim.cmd.redraw()
			return { a, b }
		]],
			{ root, directory }
		)
		local function click(button, column)
			request("nvim_input_mouse", button, "press", "", 0, 0, column)
			request("nvim_input_mouse", button, "release", "", 0, 0, column)
			lua("vim.cmd.redraw()")
		end
		click("left", 20)
		h.eq(lua("return vim.api.nvim_get_current_buf()"), ids[2])
		lua([[
            _G.tabline_test_frames = {}
            local redraw = vim.cmd.redrawtabline
            vim.cmd.redrawtabline = function()
                local text = vim.api.nvim_eval_statusline(vim.o.tabline, { use_tabline = true }).str
                table.insert(_G.tabline_test_frames, text)
                redraw()
            end
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { "changed" })
        ]])
		local function wait_for_marker(modified)
			return vim.wait(1000, function()
				return lua(
					[[
                    local frames = _G.tabline_test_frames
                    return #frames > 0 and (frames[#frames]:find(" ●", 1, true) ~= nil) == ...
                ]],
					{ modified }
				)
			end)
		end
		h.ok(wait_for_marker(true), "editing should redraw the modified marker")
		click("middle", 20)
		h.ok(lua("return vim.api.nvim_buf_is_valid(...)", { ids[2] }))
		lua([[
            _G.tabline_test_frames = {}
            vim.cmd("silent write")
        ]])
		h.ok(wait_for_marker(false), "writing should redraw without the modified marker")
		click("middle", 20)
		h.ok(not lua("return vim.api.nvim_buf_is_valid(...)", { ids[2] }))
		h.ok(not lua("return require('tabline').render():find('second.lua', 1, true) ~= nil"))
		h.eq(lua("return vim.v.errmsg"), "")
	end, debug.traceback)
	vim.fn.jobstop(job)
	vim.fn.delete(directory, "rf")
	if not ok then
		error(err)
	end
end)
