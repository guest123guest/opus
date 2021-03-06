local json = require('json')
local Util = require('util')

-- Limit queries to once per minecraft day
-- TODO: will not work if time is stopped

local TREE_URL = 'https://api.github.com/repos/%s/%s/git/trees/%s?recursive=1'
local FILE_URL = 'https://raw.githubusercontent.com/%s/%s/%s/%s'
local git = { }

local fs = _G.fs
local os = _G.os

if not _G.GIT then
	_G.GIT = { }
end

function git.list(repository)
	local t = Util.split(repository, '(.-)/')

	local user = table.remove(t, 1)
	local repo = table.remove(t, 1)
	local branch = table.remove(t, 1) or 'master'
	local path

	if not Util.empty(t) then
		path = table.concat(t, '/') .. '/'
	end

	local cacheKey = table.concat({ user, repo, branch }, '-')
	local fname = fs.combine('.git', cacheKey)

	local function getContents()
		if fs.exists(fname) then
			local contents = Util.readTable(fname)
			if contents and contents.data == os.day() then
				return contents.data
			end
			fs.delete(fname)
		end
		local dataUrl = string.format(TREE_URL, user, repo, branch)
		local contents = Util.download(dataUrl)
		if contents then
			return json.decode(contents)
		end
	end

	local data = getContents() or error('Invalid repository')

	if data.message and data.message:find("API rate limit exceeded") then
		error("Out of API calls, try again later")
	end

	if data.message and data.message == "Not found" then
		error("Invalid repository")
	end

	if not fs.exists(fname) then
		Util.writeTable('.git/' .. cacheKey, { day = os.day(), data = data })
	end

	local list = { }
	for _,v in pairs(data.tree) do
		if v.type == "blob" then
			v.path = v.path:gsub("%s","%%20")
			if not path then
				list[v.path] = {
					url = string.format(FILE_URL, user, repo, branch, v.path),
					size = v.size,
				}
			elseif Util.startsWith(v.path, path) then
				local p = string.sub(v.path, #path)
				list[p] = {
					url = string.format(FILE_URL, user, repo, branch, path .. p),
					size = v.size,
				}
			end
		end
	end

	return list
end

return git
