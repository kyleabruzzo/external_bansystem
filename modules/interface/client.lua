local logger = require("modules.utility.shared.logger")
local config = require("shared.config")

if IsInitialized('interface') then
    return require("_loadedModules")['modules.interface.client']
end

local interface = {
    store = {
        visible = false,
        loaded = false,
        currentTarget = nil,
        banList = {},
        activeTab = 'ban'
    }
}

local recentNotifications = {}

function interface:openBanUI(targetData, banlist)
    self.store.currentTarget = targetData or nil
    local result = lib.callback.await('ban:getBanList', false)
    self.store.banList = result or {}
    self:toggle(true)
end

function interface:updateBanList(banlist)
    if banlist and type(banlist) == "table" then
        self.store.banList = banlist
        
        if self.store.visible then
            logger:info("Updating ban list in UI with " .. #banlist .. " items")
            SendNUIMessage({
                action = 'updateBanList',
                bans = banlist
            })
        end
    else
        logger:warn("Received invalid banlist data")
    end
end

function interface:setActiveTab(tab)
    self.store.activeTab = tab
    
    if self.store.visible then
        SendNUIMessage({
            action = 'switchTab',
            tab = tab
        })
    end
end

function interface:toggle(state)
    self.store.visible = state
    
    SendNUIMessage({
        action = state and 'openBanMenu' or 'closeBanMenu',
        target = self.store.currentTarget,
        bans = self.store.banList,
        activeTab = self.store.activeTab,
        config = state and { durations = config.UI.durations } or nil
    })
    
    SetNuiFocus(state, state)
    
    if state then
        PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", false)
    else
        PlaySoundFrontend(-1, "BACK", "HUD_FRONTEND_DEFAULT_SOUNDSET", false)
    end
    
    logger:info("Ban interface toggled:", state)
end

function interface:showNotification(type, title, message)
    local notificationId = type .. title .. message
    
    local currentTime = GetGameTimer()
    if recentNotifications[notificationId] and (currentTime - recentNotifications[notificationId]) < 2000 then
        logger:info("Prevented duplicate notification:", title)
        return
    end
    
    recentNotifications[notificationId] = currentTime
    
    if self.store.visible then
        SendNUIMessage({
            action = 'notification',
            type = type,
            title = title,
            message = message
        })
    end
end

function interface:registerKeybinds()
    RegisterKeyMapping('togglebanmenu', 'Toggle Ban Menu', 'keyboard', config.Keybind)
    
    RegisterCommand('togglebanmenu', function()
        if self.store.visible then
            self:toggle(false)
        else
            TriggerServerEvent('ban:openMenu')
        end
    end, false)
        
    logger:info("Keybinds registered successfully")
    return true
end

function interface:registerCallbacks()
    RegisterNUICallback('appLoaded', function(_, cb)
        self.store.loaded = true
        logger:success("Ban system NUI loaded")
        cb({})
    end)

    RegisterNUICallback('exitUI', function(_, cb)
        self:toggle(false)
        cb({})
    end)

    RegisterNUICallback('submitBan', function(data, cb)
        TriggerServerEvent('ban:submitBan', data)
        cb({success = true})
        
        
    end)
    
    RegisterNUICallback('submitUnban', function(data, cb)
        TriggerServerEvent('ban:submitUnban', data.banId)
        cb({success = true})
    end)
    
    RegisterNUICallback('editBan', function(data, cb)
        TriggerServerEvent('ban:editBan', data)
        cb({success = true})
    end)
    
    RegisterNUICallback('refreshBanList', function(_, cb)
        TriggerServerEvent('ban:refreshBanList')
        Wait(100)
        cb({success = true})
    end)
    
    RegisterNUICallback('getPlayers', function(_, cb)
        local players = {}
        
        for _, playerId in ipairs(GetActivePlayers()) do
            table.insert(players, {
                id = GetPlayerServerId(playerId),
                name = GetPlayerName(playerId)
            })
        end
        
        cb({
            success = true,
            data = players
        })
    end)

    RegisterNUICallback('getPlayerIdentifiers', function(data, cb)
        local playerId = data.playerId
        if playerId then
            local playerIdentifiers = lib.callback.await('ban:getPlayerIdentifiers', false, playerId)
            if playerIdentifiers then
                cb({
                    success = true,
                    target = {
                        source = playerId,
                        name = GetPlayerName(GetPlayerFromServerId(playerId)),
                        identifiers = playerIdentifiers
                    }
                })
            else
                cb({success = false})
            end
        else
            cb({success = false})
        end
    end)
    
    RegisterNUICallback('switchTab', function(data, cb)
        self:setActiveTab(data.tab)
        cb({success = true})
    end)
    
    RegisterEventOnce('ban:banSuccess', function(data)
        if interface.store.visible then
            Wait(500)
            TriggerServerEvent('ban:refreshBanList')
        end
    end)
    
    RegisterEventOnce('ban:unbanSuccess', function(data)
        if interface.store.visible then
            TriggerServerEvent('ban:refreshBanList')
        end
    end)
    
    RegisterEventOnce('ban:editSuccess', function(data)
        if interface.store.visible then
            TriggerServerEvent('ban:refreshBanList')
        end
    end)
    
    logger:info("Callbacks registered successfully")
    return true
end

function interface.new()
    local self = setmetatable({}, { __index = interface })
    
    if not self:registerCallbacks() then
        logger:error("registerCallbacks not loaded correctly")
        return nil
    end
    
    if not self:registerKeybinds() then
        logger:error("registerKeybinds not loaded correctly")
        return nil
    end
    
    MarkInitialized('interface')
    return self
end

return interface.new()