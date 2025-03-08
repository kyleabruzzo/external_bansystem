
local _originalRequire = require
local _loadedModules = {}

function require(modulePath)
    local normalizedPath = string.lower(modulePath)
    
    if _loadedModules[normalizedPath] then
        return _loadedModules[normalizedPath]
    end
    
    local module = _originalRequire(modulePath)
    
    _loadedModules[normalizedPath] = module
    
    return module
end