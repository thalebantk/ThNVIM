-- nvim-ts-autotag -- close and rename JSX and HTML tags while typing.
--
-- Typing the ">" of "<div" writes the "</div>" after the cursor, and renaming
-- an opening tag rewrites its closing partner to match. nvim-autopairs does
-- the same job for brackets and quotes but knows nothing about tags, so the
-- two are complementary rather than competing.
--
-- Treesitter-backed: it asks the tree which element the cursor is in rather
-- than pattern-matching the text, which is what lets it cope with nested and
-- multi-line JSX. That makes it lean on the same parsers, and the same
-- filetype-to-language registration in init.lua, that indent-blankline's scope
-- highlighting needs. Without a tsx parser present it is simply inert.
--
-- Deliberately not restricted to Next.js projects, unlike ts_ls and Prettier.
-- Those two either attach to a whole tree or rewrite a whole file on save;
-- this only ever inserts the characters that were already being typed, so
-- there is nothing here to protect someone else's repository from.
return {
	{
		"windwp/nvim-ts-autotag",
		event = "InsertEnter",
		opts = {},
	},
}
