-- Utility functions

local Package = {}

-- System
----------

function Package.is_module_available(name)
	if package.loaded[name] then
		return true
	else
		for _, searcher in ipairs(package.searchers or package.loaders) do
			local loader = searcher(name)
			if type(loader) == 'function' then
				return true
			end
		end
		return false
	end
end

return Package
