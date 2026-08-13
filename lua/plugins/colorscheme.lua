-- moonfly -- colour scheme
--
-- Loaded eagerly at high priority so it is applied before any other plugin
-- draws, otherwise the first frames render in the default scheme.
return {
	{
		"bluz71/vim-moonfly-colors",
		name = "moonfly",
		lazy = false,
		priority = 1000,
		config = function()
			vim.cmd.colorscheme("moonfly")
		end,
	},
}
