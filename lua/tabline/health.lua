local M = {}

function M.check()
	vim.health.start("tabline.nvim")
	if vim.fn.has("nvim-0.10") == 1 then
		vim.health.ok("Neovim >= 0.10")
	else
		vim.health.error("Neovim >= 0.10 is required")
	end
	if vim.o.tabline:find("v:lua.require'tabline'.render()", 1, true) then
		vim.health.ok("Tabline expression installed")
	else
		vim.health.warn("Tabline expression is not installed", { 'Call require("tabline").setup()' })
	end
	if vim.o.showtabline ~= 2 then
		vim.health.info("'showtabline' is not 2; visibility follows Neovim's tab-page count")
	end
	if vim.o.mouse == "" then
		vim.health.info("Mouse support is disabled; set 'mouse' to use clickable labels")
	end
	vim.health.info("Icons are optional: mini.icons, nvim-web-devicons, or an icons callback")
end

return M
