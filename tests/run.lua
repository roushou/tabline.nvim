local harness = require("tests.harness")
require("tests.spec_tabline")
require("tests.spec_mouse")
if not harness.run() then
	vim.cmd.cquit()
end
vim.cmd("qall!")
