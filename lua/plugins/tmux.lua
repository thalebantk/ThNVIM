-- vim-tmux-navigator -- move between Neovim splits and tmux panes with one set
-- of keys.
--
-- <C-h/j/k/l> moves to the split in that direction, and steps out into the
-- neighbouring tmux pane when there is no split left to move to.
--
-- This half only handles the Neovim side. tmux needs matching bindings in
-- tmux.conf, otherwise the keys do nothing once focus is in a tmux pane.
return {
	{
		"christoomey/vim-tmux-navigator",
		cmd = {
			"TmuxNavigateLeft",
			"TmuxNavigateDown",
			"TmuxNavigateUp",
			"TmuxNavigateRight",
			"TmuxNavigatePrevious",
		},
		keys = {
			{ "<C-h>", "<cmd>TmuxNavigateLeft<cr>", desc = "Go to left split/pane" },
			{ "<C-j>", "<cmd>TmuxNavigateDown<cr>", desc = "Go to lower split/pane" },
			{ "<C-k>", "<cmd>TmuxNavigateUp<cr>", desc = "Go to upper split/pane" },
			{ "<C-l>", "<cmd>TmuxNavigateRight<cr>", desc = "Go to right split/pane" },
			{ "<C-\\>", "<cmd>TmuxNavigatePrevious<cr>", desc = "Go to previous split/pane" },
		},
	},
}
