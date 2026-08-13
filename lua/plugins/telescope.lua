-- telescope -- fuzzy finder
--
-- live_grep shells out to ripgrep and find_files to fd; install.sh installs
-- both.
return {
	{
		"nvim-telescope/telescope.nvim",
		dependencies = { "nvim-lua/plenary.nvim" },
		cmd = "Telescope",
		keys = {
			{ "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find files" },
			{ "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Grep in project" },
			{ "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Open buffers" },
			{ "<leader>fh", "<cmd>Telescope help_tags<cr>", desc = "Help tags" },
			{ "<leader>fr", "<cmd>Telescope resume<cr>", desc = "Resume last picker" },
			-- LSP pickers, useful once clangd is attached.
			{ "<leader>fs", "<cmd>Telescope lsp_document_symbols<cr>", desc = "Document symbols" },
			{ "<leader>fd", "<cmd>Telescope diagnostics bufnr=0<cr>", desc = "Buffer diagnostics" },
		},
		opts = {
			defaults = {
				-- Horizontal preview wastes width on 80-column C; put the
				-- preview above the results instead.
				layout_strategy = "vertical",
				layout_config = { vertical = { width = 0.9, preview_height = 0.5 } },
				-- hidden = true below otherwise drags in the whole of .git/.
				file_ignore_patterns = { "%.git/" },
			},
			pickers = {
				-- Dotfiles are worth finding; .git internals are not.
				find_files = { hidden = true },
			},
		},
	},
}
