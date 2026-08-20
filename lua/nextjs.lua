-- Next.js project detection, shared by lsp/ts_ls.lua and
-- lua/plugins/format.lua.
--
-- Both the language server and format-on-save are deliberately restricted to
-- Next.js trees, so both need the same answer to "which project is this file
-- in, and is it a Next.js one". Keeping the logic in one place means the two
-- can never drift into disagreeing -- a file that gets Prettier on save but no
-- server, or the reverse, would be a confusing state to debug.
--
-- Lives outside lua/plugins/ because lazy imports that directory and would try
-- to read this as a plugin spec.

local M = {}

-- Keyed by the file's directory, since the answer is a property of the tree
-- rather than the file: root() runs on every write and on every buffer that
-- could start a server, and walking upwards through the filesystem each time
-- is wasted work. Values are the root path, or false for "checked, not a
-- Next.js project" -- nil has to stay distinct from that to mean "not yet
-- checked".
local cache = {}

--- Returns the Next.js project root containing a path, or nil.
---@param path string?
---@return string?
function M.root(path)
	if not path or path == "" then
		return nil
	end

	local dir = vim.fs.dirname(path)
	local cached = cache[dir]
	if cached ~= nil then
		return cached or nil
	end

	local found = false

	-- next.config.{js,mjs,cjs,ts,mts} is what create-next-app writes and the
	-- one file no other framework has, so it settles the question on its own.
	local cfg = vim.fs.find(function(name)
		return name:match("^next%.config%.%w+$") ~= nil
	end, { path = dir, upward = true, type = "file" })[1]

	if cfg then
		found = vim.fs.dirname(cfg)
	else
		-- A project that needs no options can delete next.config entirely,
		-- so fall back to asking package.json whether next is a dependency.
		local pkg = vim.fs.find("package.json", { path = dir, upward = true, type = "file" })[1]
		if pkg then
			local ok, decoded = pcall(function()
				return vim.json.decode(table.concat(vim.fn.readfile(pkg), "\n"))
			end)
			if ok and type(decoded) == "table" then
				local deps = decoded.dependencies or {}
				local dev = decoded.devDependencies or {}
				if deps.next ~= nil or dev.next ~= nil then
					found = vim.fs.dirname(pkg)
				end
			end
		end
	end

	cache[dir] = found
	return found or nil
end

--- Whether a buffer's file sits inside a Next.js project.
---@param bufnr integer
---@return boolean
function M.is_project(bufnr)
	return M.root(vim.api.nvim_buf_get_name(bufnr)) ~= nil
end

return M
