local logger = require("modules.utility.shared.logger")
local interface = require("modules.interface.client")

if IsInitialized('ban_client') then
    return require("_loadedModules")['modules.ban.client']
end

local BanModule = {}

function BanModule:init()
    self:setupEventHandlers()
    logger:info("Ban module client initialized")
    MarkInitialized('ban_client')
end

function BanModule:setupEventHandlers()
    RegisterEventOnce("ban:showMenu", function(targetData, banlist)
        interface:openBanUI(targetData, banlist)
    end)
    
    RegisterEventOnce("ban:updateBanList", function(banlist)
        interface:updateBanList(banlist)
    end)
end

local instance = {}
setmetatable(instance, { __index = BanModule })
instance:init()

return instance