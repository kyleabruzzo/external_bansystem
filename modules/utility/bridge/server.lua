local logger = require("modules.utility.shared.logger")

if IsInitialized('server_bridge') then
    return require("_loadedModules")['modules.utility.bridge.server']
end

local bridge = {}

bridge.framework = nil
bridge.frameworkObject = nil

function bridge.setup()
    if GetResourceState('es_extended') == 'started' then
        bridge.framework = 'esx'
        bridge.frameworkObject = exports['es_extended']:getSharedObject()
        logger:success("Server Bridge: ESX framework detected")
    elseif GetResourceState('qb-core') == 'started' then
        bridge.framework = 'qbcore'
        bridge.frameworkObject = exports['qb-core']:GetCoreObject()
        logger:success("Server Bridge: QB-Core framework detected")
    else
        logger:warn("Server Bridge: No supported framework detected! (ESX/QB-Core)")
    end
end

function bridge.getPlayer(source)
    if not bridge.framework then bridge.setup() end
    
    if bridge.framework == 'esx' then
        return bridge.frameworkObject.GetPlayerFromId(source)
    elseif bridge.framework == 'qbcore' then
        return bridge.frameworkObject.Functions.GetPlayer(source)
    end
    return nil
end

function bridge.getPlayerGroup(player)
    if not player then return nil end
    
    if bridge.framework == 'esx' then
        return player.getGroup()
    elseif bridge.framework == 'qbcore' then
        return player.PlayerData.permission
    end
    return nil
end

function bridge.hasPermission(source, permission)
    local player = bridge.getPlayer(source)
    if not player then 
        logger:info("Player not found for source:", source)
        return false 
    end
    
    if bridge.framework == 'esx' then
        local hasPermission = player.getGroup() == permission
        logger:info("ESX permission check for player:", player.identifier, "Permission:", tostring(permission), "Result:", hasPermission)
        return hasPermission
    elseif bridge.framework == 'qbcore' then
        local hasPermission = bridge.frameworkObject.Functions.HasPermission(source, permission)
        logger:info("QB-Core permission check for source:", source, "Permission:", tostring(permission), "Result:", hasPermission)
        return hasPermission
    end
    
    local acePermission = IsPlayerAceAllowed(source, "group." .. permission)
    logger:info("Ace permission check for source:", source, "Permission:", tostring(permission), "Result:", acePermission)
    return acePermission
end

function bridge.getFrameworkName()
    if not bridge.framework then bridge.setup() end
    return bridge.framework
end

bridge.setup()

if lib then
    lib.callback.register('bridge:hasPermission', function(source, permx)
        return bridge.hasPermission(source, permx)
    end)
end

MarkInitialized('server_bridge')

return bridge