-- tailwindcss-language-server -- class name completion, hover showing the CSS
-- a class actually generates, colour swatches in the sign column, and warnings
-- about conflicting utilities in the same className.
--
-- Resolved by vim.lsp.enable("tailwindcss") in init.lua. Requires the
-- tailwindcss-language-server binary; install.sh installs it with npm into
-- ~/.local alongside the TypeScript server.

local ok, blink = pcall(require, "blink.cmp")
local capabilities = ok and blink.get_lsp_capabilities() or nil

-- Whether a project root actually uses Tailwind. Cached per root: this runs
-- for every buffer that could start the server.
local uses_tailwind = {}

local function has_tailwind(root)
	if uses_tailwind[root] ~= nil then
		return uses_tailwind[root]
	end

	local found = false

	-- Tailwind 3 keeps a tailwind.config.{js,cjs,mjs,ts}. Tailwind 4 dropped
	-- it in favour of configuring from the CSS file itself, so its absence
	-- proves nothing and the dependency list is the reliable test for both.
	if vim.fn.glob(root .. "/tailwind.config.*") ~= "" then
		found = true
	else
		local pkg = root .. "/package.json"
		if vim.uv.fs_stat(pkg) then
			local decoded_ok, decoded = pcall(function()
				return vim.json.decode(table.concat(vim.fn.readfile(pkg), "\n"))
			end)
			if decoded_ok and type(decoded) == "table" then
				local deps = decoded.dependencies or {}
				local dev = decoded.devDependencies or {}
				found = deps.tailwindcss ~= nil or dev.tailwindcss ~= nil
			end
		end
	end

	uses_tailwind[root] = found
	return found
end

return {
	cmd = { "tailwindcss-language-server", "--stdio" },
	filetypes = {
		"css",
		"scss",
		"html",
		"javascript",
		"javascriptreact",
		"typescript",
		"typescriptreact",
	},
	-- Two conditions, both required. The Next.js one keeps this consistent
	-- with lsp/ts_ls.lua -- one restriction, applied the same way, rather than
	-- each server picking its own idea of where it belongs. The Tailwind one
	-- stops the server starting in a Next.js app that does not use Tailwind at
	-- all, where it would sit there answering nothing.
	root_dir = function(bufnr, on_dir)
		local root = require("nextjs").root(vim.api.nvim_buf_get_name(bufnr))
		if root and has_tailwind(root) then
			on_dir(root)
		end
	end,
	settings = {
		tailwindCSS = {
			-- Flags utilities that fight each other in one className, which
			-- is the mistake Tailwind makes easy: "px-2 p-4" silently keeps
			-- only one of them.
			validate = true,
			-- className is React's spelling; class is there for the plain
			-- .html and .css files that share this server.
			classAttributes = { "class", "className", "classList", "ngClass" },
			-- The server asks what a filetype should be treated as when
			-- scanning for classes. JSX is not a language it knows by name.
			includeLanguages = {
				javascriptreact = "javascript",
				typescriptreact = "javascript",
			},
		},
	},
	capabilities = capabilities,
}
