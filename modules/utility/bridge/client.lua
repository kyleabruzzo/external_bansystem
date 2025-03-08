local logger = require("modules.utility.shared.logger")

if IsInitialized('client_bridge') then
    return require("_loadedModules")['modules.utility.bridge.client']
end

local bridge = {}

bridge.framework = nil
bridge.frameworkObject = nil

function bridge.detectFramework()
    if GetResourceState('es_extended') == 'started' then
        bridge.framework = 'esx'
        bridge.frameworkObject = exports['es_extended']:getSharedObject()
        logger:success("Client Bridge: ESX framework detected")
    elseif GetResourceState('qb-core') == 'started' then
        bridge.framework = 'qbcore'
        bridge.frameworkObject = exports['qb-core']:GetCoreObject()
        logger:success("Client Bridge: QB-Core framework detected")
    else
        logger:warn("Client Bridge: No supported framework detected")
    end
end

function bridge.getPlayerData()
    if not bridge.framework then
        bridge.detectFramework()
    end
    
    if bridge.framework == 'esx' then
        return bridge.frameworkObject.GetPlayerData()
    elseif bridge.framework == 'qbcore' then
        return bridge.frameworkObject.Functions.GetPlayerData()
    end
    
    return nil
end

function bridge.getPlayerGroup()
    local playerData = bridge.getPlayerData()
    
    if not playerData then return nil end
    
    if bridge.framework == 'esx' then
        return playerData.group
    elseif bridge.framework == 'qbcore' then
        return playerData.permission
    end
    
    return nil
end

function bridge.hasPermission(permission)
    return lib.callback.await('bridge:hasPermission', false, permission)
end

function bridge.notify(message, type)
    type = type or 'info'
    
    if bridge.framework == 'esx' then
        bridge.frameworkObject.ShowNotification(message)
    elseif bridge.framework == 'qbcore' then
        bridge.frameworkObject.Functions.Notify(message, type)
    else
        SetNotificationTextEntry('STRING')
        AddTextComponentString(message)
        DrawNotification(false, false)
    end
end

bridge.detectFramework()
MarkInitialized('client_bridge')

return bridge