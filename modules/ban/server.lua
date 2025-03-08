local logger = require("modules.utility.shared.logger")
local bridge = require("modules.utility.bridge.server")
local webhook = require("modules.webhook.server")
local config = require("shared.config")

if IsInitialized('ban_server') then
    return require("_loadedModules")['modules.ban.server']
end

local BanModule = {}
BanModule.__index = BanModule

local registeredServerEvents = {}

function BanModule.new()
    local self = setmetatable({}, BanModule)
    self.bans = {}
    return self
end

function BanModule:init()
    if self.initialized then return end  
    self.initialized = true
    self.bans = {}
    
    self:setupDatabase(function()
        self:loadBans()
    end)
    self:registerCommands()
    self:startBanRefreshTimer()
    self:setupEventHandlers()
    logger:success("Ban module initialized")
    MarkInitialized('ban_server')
end

function BanModule:setupDatabase(callback)
    local tableName = "ban_system"
    
    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS ]] .. tableName .. [[ (
            id INT AUTO_INCREMENT PRIMARY KEY,
            ban_id VARCHAR(12) NOT NULL,
            identifiers TEXT NOT NULL,
            target_name VARCHAR(255) NOT NULL,
            reason TEXT NOT NULL,
            admin_name VARCHAR(255) NOT NULL,
            admin_identifier VARCHAR(100) NOT NULL, 
            ban_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            unban_date TIMESTAMP NULL,
            is_active BOOLEAN DEFAULT TRUE,
            duration VARCHAR(50) NULL
        )
    ]], {}, function(result)
        if result then
            logger:success("Ban system database setup complete")
            if callback then
                callback()
            end
        else
            logger:error("Failed to setup ban system database")
        end
    end)
end

function BanModule:loadBans()
    self.bans = {}
    exports.oxmysql:execute('SELECT * FROM ban_system WHERE is_active = ?', {1}, function(result)
        if result and #result > 0 then
            for _, banData in ipairs(result) do
                if banData.identifiers then
                    local identifiers = json.decode(banData.identifiers)
                    if identifiers then
                        for _, id in ipairs(identifiers) do
                            self.bans[id] = banData
                        end
                    end
                end
            end
            logger:info("Loaded " .. #result .. " active bans")
        else
            logger:info("No active bans found")
        end
    end)
end

function BanModule:registerCommands()
    RegisterCommand(config.Commands.ban, function(source, args, rawCommand)
        local adminSource = source
        if adminSource <= 0 then
            adminSource = nil
        end
        
        self:handleBanCommand(adminSource, args)
    end, config.AdminOnly)
    
    RegisterCommand(config.Commands.unban, function(source, args, rawCommand)
        local adminSource = source
        if adminSource <= 0 then
            adminSource = nil
        end
        
        self:handleUnbanCommand(adminSource, args)
    end, config.AdminOnly)
end

function BanModule:setupEventHandlers()
    local function registerEventOnce(eventName, handler)
        if registeredServerEvents[eventName] then
            return
        end
        
        registeredServerEvents[eventName] = true
        RegisterNetEvent(eventName)
        AddEventHandler(eventName, handler)
    end

    AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
        local source = source
        local identifiers = self:getPlayerIdentifiers(source)
        deferrals.defer()
        
        local initialCard = [[
        {
            "type": "AdaptiveCard",
            "version": "1.4",
            "body": [
                {
                    "type": "TextBlock",
                    "text": "🛠️ Establishing connection...",
                    "weight": "Bolder",
                    "size": "Medium"
                },
                {
                    "type": "TextBlock",
                    "text": "Please wait while we verify your account",
                    "wrap": true
                },
                {
                    "type": "ProgressBar",
                    "value": 0.1
                }
            ]
        }
        ]]
        deferrals.presentCard(initialCard)
        Wait(2000)
    
        local verifyingCard = [[
        {
            "type": "AdaptiveCard",
            "version": "1.4",
            "body": [
                {
                    "type": "TextBlock",
                    "text": "🛠️ Connection in progress...",
                    "weight": "Bolder",
                    "size": "Medium"
                },
                {
                    "type": "TextBlock",
                    "text": "🔍 Checking player profile...",
                    "wrap": true
                },
                {
                    "type": "ProgressBar",
                    "value": 0.3
                }
            ]
        }
        ]]
        deferrals.presentCard(verifyingCard)
        Wait(2000)
        
        local banCheckCard = [[
        {
            "type": "AdaptiveCard",
            "version": "1.4",
            "body": [
                {
                    "type": "TextBlock",
                    "text": "🛠️ Connection in progress...",
                    "weight": "Bolder",
                    "size": "Medium"
                },
                {
                    "type": "TextBlock",
                    "text": "📂 Scanning ban records database...",
                    "wrap": true
                },
                {
                    "type": "ProgressBar",
                    "value": 0.5
                }
            ]
        }
        ]]
        deferrals.presentCard(banCheckCard)
        Wait(2200)
        
        local activeBanCount = 0
        local activeBanData = nil
        local foundActiveBanIds = {}
        local activeBanIdentifier = nil
    
        for _, identifier in pairs(identifiers) do
            if self.bans[identifier] and self.bans[identifier].is_active then
                local banId = self.bans[identifier].id
                if not foundActiveBanIds[banId] then
                    activeBanCount = activeBanCount + 1
                    foundActiveBanIds[banId] = true
                end
                activeBanData = self.bans[identifier]
                activeBanIdentifier = identifier
            end
        end
        
        local identifiersForQuery = {}
        for _, id in ipairs(identifiers) do
            table.insert(identifiersForQuery, id)
        end
        
        local inactiveBanCount = 0
        local p = promise.new()
        
        if #identifiersForQuery > 0 then
            local queryParams = {}
            for i, id in ipairs(identifiersForQuery) do
                queryParams[i] = '"%' .. id .. '%"'
            end
            
            local queryStr = "SELECT COUNT(DISTINCT id) as count FROM ban_system WHERE is_active = 0 AND ("
            for i, param in ipairs(queryParams) do
                if i > 1 then
                    queryStr = queryStr .. " OR "
                end
                queryStr = queryStr .. "identifiers LIKE " .. param
            end
            queryStr = queryStr .. ")"
            
            exports.oxmysql:execute(queryStr, {}, function(result)
                if result and result[1] and result[1].count > 0 then
                    inactiveBanCount = result[1].count
                end
                p:resolve()
            end)
        else
            p:resolve()
        end
        
        Citizen.Await(p)
        
        if activeBanCount > 0 or inactiveBanCount > 0 then
            local totalBans = activeBanCount + inactiveBanCount
            local resultCard = [[
            {
                "type": "AdaptiveCard",
                "version": "1.4",
                "body": [
                    {
                        "type": "TextBlock",
                        "text": "🛠️ Connection in progress...",
                        "weight": "Bolder",
                        "size": "Medium"
                    },
                    {
                        "type": "TextBlock",
                        "text": "⚠️ Found %d ban record(s) in your history",
                        "wrap": true,
                        "color": "Warning" 
                    },
                    {
                        "type": "TextBlock",
                        "text": "Checking if any bans are currently active...",
                        "wrap": true
                    },
                    {
                        "type": "ProgressBar",
                        "value": 0.7
                    }
                ]
            }
            ]]
            deferrals.presentCard(string.format(resultCard, totalBans))
            Wait(2500)
        else
            local resultCard = [[
            {
                "type": "AdaptiveCard",
                "version": "1.4",
                "body": [
                    {
                        "type": "TextBlock",
                        "text": "🛠️ Connection in progress...",
                        "weight": "Bolder",
                        "size": "Medium"
                    },
                    {
                        "type": "TextBlock",
                        "text": "✅ No ban records found in your history",
                        "wrap": true,
                        "color": "Good"
                    },
                    {
                        "type": "TextBlock",
                        "text": "Completing connection...",
                        "wrap": true
                    },
                    {
                        "type": "ProgressBar",
                        "value": 0.9
                    }
                ]
            }
            ]]
            deferrals.presentCard(resultCard)
            Wait(3000)
        end
    
        if activeBanCount > 0 and activeBanData then
            local currentTime = os.time()
            local banDate = activeBanData.ban_date and os.date("%Y-%m-%d %H:%M:%S", math.floor(activeBanData.ban_date / 1000)) or "Unknown"
            local unbanDate = activeBanData.unban_date and math.floor(activeBanData.unban_date / 1000) or nil
            
            if unbanDate and currentTime > unbanDate then
                if activeBanIdentifier then
                    self:setUnbanned(activeBanIdentifier)
                end
                
                if inactiveBanCount > 0 then
                    local historyCard = [[
                    {
                        "type": "AdaptiveCard",
                        "version": "1.4",
                        "body": [
                            {
                                "type": "TextBlock",
                                "text": "🛠️ Connection in progress...",
                                "weight": "Bolder",
                                "size": "Medium"
                            },
                            {
                                "type": "TextBlock",
                                "text": "⚠️ You have %d previous ban(s) in your history",
                                "wrap": true,
                                "color": "Warning"
                            },
                            {
                                "type": "TextBlock",
                                "text": "All bans have expired. Connection allowed.",
                                "wrap": true
                            },
                            {
                                "type": "ProgressBar",
                                "value": 0.9
                            }
                        ]
                    }
                    ]]
                    deferrals.presentCard(string.format(historyCard, inactiveBanCount))
                    Wait(4500)
                end
                
                deferrals.done()
            else
                local timeLeft = unbanDate and self:formatTimeLeft(unbanDate - currentTime) or "Permanent"
                
                local actions = ""
                if config.UI and config.UI.appealInfo and config.UI.appealInfo.enabled and config.UI.appealInfo.showAppealButton then
                    actions = [[
                    "actions": [
                        {
                            "type": "Action.OpenUrl",
                            "title": "Appeal Ban",
                            "url": "]] .. config.UI.appealInfo.discordLink .. [["
                        }
                    ],
                    ]]
                end
                
                local appealMessage = "You cannot appeal this ban at the moment."
                if config.UI and config.UI.appealInfo and config.UI.appealInfo.enabled then
                    appealMessage = config.UI.appealInfo.message
                end
                
                local finalCard = [[
                {
                    "type": "AdaptiveCard",
                    "version": "1.4",
                    ]] .. actions .. [[
                    "body": [
                        {
                            "type": "Container",
                            "items": [
                                {
                                    "type": "TextBlock",
                                    "text": "🚫 ACCESS DENIED",
                                    "weight": "Bolder",
                                    "size": "ExtraLarge",
                                    "color": "Attention",
                                    "horizontalAlignment": "Center"
                                },
                                {
                                    "type": "TextBlock",
                                    "text": "Your account is currently banned from this server",
                                    "wrap": true,
                                    "horizontalAlignment": "Center",
                                    "spacing": "Medium"
                                }
                            ],
                            "style": "warning",
                            "bleed": true
                        },
                        {
                            "type": "ColumnSet",
                            "columns": [
                                {
                                    "type": "Column",
                                    "width": "auto",
                                    "items": [
                                        {
                                            "type": "TextBlock",
                                            "text": "Ban ID:",
                                            "weight": "Bolder"
                                        }
                                    ]
                                },
                                {
                                    "type": "Column",
                                    "width": "stretch",
                                    "items": [
                                        {
                                            "type": "TextBlock",
                                            "text": "#%s",
                                            "color": "Accent"
                                        }
                                    ]
                                }
                            ]
                        },
                        {
                            "type": "ColumnSet",
                            "columns": [
                                {
                                    "type": "Column",
                                    "width": "auto",
                                    "items": [
                                        {
                                            "type": "TextBlock",
                                            "text": "Reason:",
                                            "weight": "Bolder"
                                        }
                                    ]
                                },
                                {
                                    "type": "Column",
                                    "width": "stretch",
                                    "items": [
                                        {
                                            "type": "TextBlock",
                                            "text": "%s",
                                            "wrap": true
                                        }
                                    ]
                                }
                            ]
                        },
                        {
                            "type": "ColumnSet",
                            "columns": [
                                {
                                    "type": "Column",
                                    "width": "auto",
                                    "items": [
                                        {
                                            "type": "TextBlock",
                                            "text": "Banned by:",
                                            "weight": "Bolder"
                                        }
                                    ]
                                },
                                {
                                    "type": "Column",
                                    "width": "stretch",
                                    "items": [
                                        {
                                            "type": "TextBlock",
                                            "text": "%s"
                                        }
                                    ]
                                }
                            ]
                        },
                        {
                            "type": "ColumnSet",
                            "columns": [
                                {
                                    "type": "Column",
                                    "width": "auto",
                                    "items": [
                                        {
                                            "type": "TextBlock",
                                            "text": "Ban Date:",
                                            "weight": "Bolder"
                                        }
                                    ]
                                },
                                {
                                    "type": "Column",
                                    "width": "stretch",
                                    "items": [
                                        {
                                            "type": "TextBlock",
                                            "text": "%s"
                                        }
                                    ]
                                }
                            ]
                        },
                        {
                            "type": "ColumnSet",
                            "columns": [
                                {
                                    "type": "Column",
                                    "width": "auto",
                                    "items": [
                                        {
                                            "type": "TextBlock",
                                            "text": "Remaining Time:",
                                            "weight": "Bolder"
                                        }
                                    ]
                                },
                                {
                                    "type": "Column",
                                    "width": "stretch",
                                    "items": [
                                        {
                                            "type": "TextBlock",
                                            "text": "%s",
                                            "color": "Warning",
                                            "weight": "Bolder"
                                        }
                                    ]
                                }
                            ]
                        },
                        {
                            "type": "Container",
                            "style": "emphasis",
                            "items": [
                                {
                                    "type": "TextBlock",
                                    "text": "]] .. appealMessage .. [[",
                                    "wrap": true,
                                    "horizontalAlignment": "Center",
                                    "size": "Small",
                                    "spacing": "Small"
                                }
                            ],
                            "spacing": "Medium",
                            "separator": true
                        }
                    ]
                }
                ]]
                
                deferrals.presentCard(string.format(finalCard, 
                    activeBanData.ban_id, 
                    activeBanData.reason, 
                    activeBanData.admin_name, 
                    banDate, 
                    timeLeft)
                )
                
                print(string.format(
                    "^3[Ban System] ^7Player ^2'%s' ^7attempted to connect while being banned.\n" ..
                    "^7Ban Details:\n" ..
                    "  ^5Ban ID: ^7%s\n" ..
                    "  ^5Reason: ^7%s\n" ..
                    "  ^5Admin: ^7%s\n" ..
                    "  ^5Ban Date: ^7%s\n" ..
                    "  ^5Time Left: ^7%s\n",
                    name, 
                    activeBanData.ban_id, 
                    activeBanData.reason, 
                    activeBanData.admin_name, 
                    banDate, 
                    timeLeft
                ))
                return
            end
        elseif inactiveBanCount > 0 then
            local historyCard = [[
            {
                "type": "AdaptiveCard",
                "version": "1.4",
                "body": [
                    {
                        "type": "TextBlock",
                        "text": "🛠️ Connection in progress...",
                        "weight": "Bolder",
                        "size": "Medium"
                    },
                    {
                        "type": "TextBlock",
                        "text": "⚠️ You have %d previous ban(s) in your history",
                        "wrap": true,
                        "color": "Warning"
                    },
                    {
                        "type": "TextBlock",
                        "text": "All bans have expired. Connection allowed.",
                        "wrap": true
                    },
                    {
                        "type": "ProgressBar",
                        "value": 0.9
                    }
                ]
            }
            ]]
            deferrals.presentCard(string.format(historyCard, inactiveBanCount))
            Wait(3500)
            
            local finalCard = [[
            {
                "type": "AdaptiveCard",
                "version": "1.4",
                "body": [
                    {
                        "type": "TextBlock",
                        "text": "🛠️ Connection successful!",
                        "weight": "Bolder",
                        "size": "Medium",
                        "color": "Good"
                    },
                    {
                        "type": "TextBlock",
                        "text": "Welcome to the server, %s",
                        "wrap": true
                    },
                    {
                        "type": "ProgressBar",
                        "value": 1.0
                    }
                ]
            }
            ]]
            deferrals.presentCard(string.format(finalCard, name))
            Wait(4500)
            deferrals.done()
        else
            local finalCard = [[
            {
                "type": "AdaptiveCard",
                "version": "1.4",
                "body": [
                    {
                        "type": "TextBlock",
                        "text": "🛠️ Connection successful!",
                        "weight": "Bolder",
                        "size": "Medium",
                        "color": "Good"
                    },
                    {
                        "type": "TextBlock",
                        "text": "Welcome to the server, %s",
                        "wrap": true
                    },
                    {
                        "type": "ProgressBar",
                        "value": 1.0
                    }
                ]
            }
            ]]
            deferrals.presentCard(string.format(finalCard, name))
            Wait(5000)
            deferrals.done()
        end
    end)
    
    registerEventOnce("ban:openMenu", function(targetId)
        local source = source
        if self:isAdmin(source) then
            local targetData = nil
            if targetId and tonumber(targetId) > 0 then
                targetData = {
                    source = targetId,
                    name = GetPlayerName(targetId),
                    identifiers = self:getPlayerIdentifiers(targetId)
                }
            end

            local banList = self:getActiveBans() or {}
            TriggerClientEvent("ban:showMenu", source, targetData, banList)
        end
    end)
    
    RegisterEventOnce("ban:submitBan", function(data)
        local source = source
        if not self:isAdmin(source) then return end
        
        if data.offline then
            self:banOfflinePlayer(source, data)
        else
            self:banPlayer(source, data.targetId, data.reason, data.duration)
        end
    end)
    
    registerEventOnce("ban:submitUnban", function(banId)
        local source = source
        if not self:isAdmin(source) then return end
        
        self:unbanPlayer(source, banId)
    end)
    
    registerEventOnce("ban:editBan", function(data)
        local source = source
        if not self:isAdmin(source) then return end
        
        self:editBan(source, data.ban_id, data.reason, data.duration)
    end)
    
    RegisterEventOnce("ban:refreshBanList", function()
        local source = source
        if not self:isAdmin(source) then return end
        
        self:getActiveBans(function(banList)
            TriggerClientEvent("ban:updateBanList", source, banList)
        end)
    end)
    
    if not registeredServerEvents['callbacks_registered'] then
        registeredServerEvents['callbacks_registered'] = true
        
        lib.callback.register('ban:getPlayerIdentifiers', function(source, targetId)
            if not self:isAdmin(source) then return nil end
            
            if targetId and tonumber(targetId) > 0 then
                return self:getPlayerIdentifiers(targetId)
            end
            
            return nil
        end)
        
        lib.callback.register('ban:getBanList', function(source)
            if not self:isAdmin(source) then return {} end
            
            local promise = promise.new()
            
            self:getActiveBans(function(bans)
                promise:resolve(bans)
            end)
            
            return Citizen.Await(promise)
        end)
    end
end

function BanModule:startBanRefreshTimer()
    local refreshInterval = 60
    
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(refreshInterval * 1000)
            self:loadBans()
        end
    end)
end

function BanModule:handleBanCommand(adminSource, args)
    if #args < 2 then
        if adminSource then
            TriggerClientEvent('chat:addMessage', adminSource, {
                color = {255, 0, 0},
                multiline = true,
                args = {"System", config.Messages.banUsage}
            })
        else
            logger:info(config.Messages.banUsage)
        end
        return
    end

    local targetId = tonumber(args[1])
    table.remove(args, 1)
    local duration = nil
    
    if args[1] then
        if args[1]:lower() == "permanent" or args[1]:lower() == "perm" then
            duration = "5475d"
            table.remove(args, 1)
        elseif self:isTimeFormat(args[1]) then
            duration = args[1]
            table.remove(args, 1)
        end
    end
    
    local reason = table.concat(args, " ")
    
    if reason == "" or not reason then
        if adminSource then
            TriggerClientEvent('chat:addMessage', adminSource, {
                color = {255, 0, 0},
                multiline = true,
                args = {"System", "You must provide a ban reason."}
            })
        else
            logger:error("Failed to ban: No reason provided")
        end
        return
    end
    
    if targetId and targetId > 0 then
        self:banPlayer(adminSource, targetId, reason, duration)
    else
        if adminSource then
            TriggerClientEvent('chat:addMessage', adminSource, {
                color = {255, 0, 0},
                multiline = true,
                args = {"System", config.Messages.playerNotFound}
            })
        else
            logger:error(config.Messages.playerNotFound)
        end
    end
end

function BanModule:handleUnbanCommand(adminSource, args)
    if #args < 1 then
        if adminSource then
            TriggerClientEvent('chat:addMessage', adminSource, {
                color = {255, 0, 0},
                multiline = true,
                args = {"System", config.Messages.unbanUsage}
            })
        else
            logger:error(config.Messages.unbanUsage)
        end
        return
    end
    
    local banId = tostring(args[1])
    if not banId then
        if adminSource then
            TriggerClientEvent('chat:addMessage', adminSource, {
                color = {255, 0, 0},
                multiline = true,
                args = {"System", "Invalid Ban ID format."}
            })
        else
            logger:error("Invalid Ban ID format.")
        end
        return
    end
    
    self:unbanPlayer(adminSource, banId)
end

function BanModule:generateBanId()
    local code = {}
    for i = 1, 3 do
        local group = ""
        for j = 1, 3 do
            local isLetter = math.random(2) == 1
            local randomChar
            if isLetter then
                randomChar = string.char(math.random(65, 90))
            else
                randomChar = math.random(0, 9) 
            end
            group = group .. randomChar
        end
        table.insert(code, group)
    end
    return table.concat(code, "-") 
end

function BanModule:banPlayer(adminSource, targetId, reason, duration)
    local targetName = GetPlayerName(targetId)
    if not targetName then
        if adminSource then
            TriggerClientEvent('chat:addMessage', adminSource, {
                color = {255, 0, 0},
                multiline = true,
                args = {"System", config.Messages.playerNotFound}
            })
        else
            logger:error(config.Messages.playerNotFound)
        end
        return
    end
    
    local adminName = "Console"
    local adminIdentifier = "console"
    
    if adminSource then
        adminName = GetPlayerName(adminSource)
        adminIdentifier = self:getMainIdentifier(adminSource)
    end
    
    local targetIdentifiers = self:getPlayerIdentifiers(targetId)
    local allIdentifiersJson = json.encode(targetIdentifiers)
    local banID = self:generateBanId()

    if #targetIdentifiers == 0 then
        if adminSource then
            TriggerClientEvent('chat:addMessage', adminSource, {
                color = {255, 0, 0},
                multiline = true,
                args = {"System", config.Messages.identifierError}
            })
        else
            logger:error(config.Messages.identifierError)
        end
        return
    end
    
    local unbanDate = nil
    if duration then
        unbanDate = self:calculateUnbanDate(duration)
    end
    
    self:insertBanRecord(banID, allIdentifiersJson, targetName, reason, adminName, adminIdentifier, unbanDate, duration)
    
    local banMessage = string.format(config.Messages.banned, 
        banID,
        reason, 
        adminName, 
        os.date("%Y-%m-%d %H:%M:%S"), 
        duration and self:formatTimeLeft(self:parseDuration(duration)) or "permanent")
    
    DropPlayer(targetId, banMessage)
    
    webhook:sendBanWebhook(banID, targetName, allIdentifiersJson, reason, duration, adminName)
    
    if adminSource then
        TriggerClientEvent('ban:banSuccess', adminSource, {
            targetName = targetName,
            reason = reason,
            duration = duration
        })
    end
end

function BanModule:banOfflinePlayer(adminSource, data)
    local adminName = "Console"
    local adminIdentifier = "console"
    
    if adminSource then
        adminName = GetPlayerName(adminSource)
        adminIdentifier = self:getMainIdentifier(adminSource)
    end
    
    local banID = self:generateBanId()
    local targetName = data.playerName or "Unknown (Offline)"
    
    -- Create identifiers array from the provided data
    local identifiers = {}
    
    -- Add each provided identifier to the array
    if data.license then table.insert(identifiers, "license:" .. data.license) end
    if data.license2 then table.insert(identifiers, "license2:" .. data.license2) end
    if data.steam then table.insert(identifiers, "steam:" .. data.steam) end
    if data.ip then table.insert(identifiers, "ip:" .. data.ip) end
    if data.xbl then table.insert(identifiers, "xbl:" .. data.xbl) end
    if data.discord then table.insert(identifiers, "discord:" .. data.discord) end
    
    if #identifiers == 0 and data.identifier then
        table.insert(identifiers, data.identifier)
    elseif #identifiers == 0 then
        if adminSource then
            TriggerClientEvent('chat:addMessage', adminSource, {
                color = {255, 0, 0},
                multiline = true,
                args = {"System", "At least one identifier is required for an offline ban."}
            })
        end
        return
    end
    
    local identifiersJson = json.encode(identifiers)
    
    local unbanDate = nil
    if data.duration then
        unbanDate = self:calculateUnbanDate(data.duration)
    end
    
    self:insertBanRecord(banID, identifiersJson, targetName, data.reason, adminName, adminIdentifier, unbanDate, data.duration)
    webhook:sendBanWebhook(banID, targetName, identifiersJson, data.reason, data.duration, adminName)
    if adminSource then
        TriggerClientEvent('ban:banSuccess', adminSource, {
            targetName = targetName,
            reason = data.reason,
            duration = data.duration
        })
    end
end

function BanModule:unbanPlayer(adminSource, banId)
    exports.oxmysql:execute('SELECT * FROM ban_system WHERE ban_id = ? AND is_active = ? LIMIT 1', {banId, 1}, function(result)
        if result and result[1] then
            self:setUnbannedById(banId, function()
                self:getActiveBans(function(updatedBans)
                    local adminName = "Console"
                    
                    if adminSource then
                        adminName = GetPlayerName(adminSource)
                        
                        TriggerClientEvent('ban:updateBanList', adminSource, updatedBans)
                        
                        TriggerClientEvent('chat:addMessage', adminSource, {
                            color = {0, 255, 0},
                            multiline = true,
                            args = {"System", string.format(config.Messages.unbanSuccess, result[1].target_name)}
                        })
                        
                        TriggerClientEvent('ban:unbanSuccess', adminSource, {
                            targetName = result[1].target_name
                        })
                    else
                        logger:info(string.format(config.Messages.unbanSuccess, result[1].target_name))
                    end
                    
                    webhook:sendUnbanWebhook(result[1].ban_id, result[1].target_name, result[1].identifiers, adminName)
                end)
            end)
        else
            if adminSource then
                TriggerClientEvent('chat:addMessage', adminSource, {
                    color = {255, 0, 0},
                    multiline = true,
                    args = {"System", config.Messages.notBanned}
                })
            else
                logger:error(config.Messages.notBanned)
            end
        end
    end)
end

function BanModule:setUnbannedById(banId, callback)
    exports.oxmysql:execute('UPDATE ban_system SET is_active = 0 WHERE ban_id = ?', {banId}, function()
        exports.oxmysql:execute('SELECT identifiers FROM ban_system WHERE ban_id = ?', {banId}, function(result)
            if result and result[1] then
                local identifiers = json.decode(result[1].identifiers)
                if identifiers then
                    for _, id in ipairs(identifiers) do
                        self.bans[id] = nil
                    end
                end
            end
            self:loadBans()
            
            if callback then
                callback()
            end
        end)
    end)
end

function BanModule:editBan(adminSource, banId, reason, duration)
    exports.oxmysql:execute('SELECT * FROM ban_system WHERE ban_id = ? AND is_active = ? LIMIT 1', {banId, 1}, function(result)
        if result and result[1] then
            local unbanDate = nil
            if duration then
                unbanDate = self:calculateUnbanDate(duration)
            end
            
            exports.oxmysql:execute('UPDATE ban_system SET reason = ?, unban_date = ?, duration = ? WHERE ban_id = ? AND is_active = 1', 
                {reason, unbanDate, duration, banId}, 
                function(updateResult)
                    if updateResult and updateResult.affectedRows > 0 then
                        local identifiers = json.decode(result[1].identifiers)
                        if identifiers then
                            for _, id in ipairs(identifiers) do
                                if self.bans[id] then
                                    self.bans[id].reason = reason
                                    self.bans[id].unban_date = unbanDate
                                    self.bans[id].duration = duration
                                end
                            end
                        end
                        
                        local adminName = "Console"
                        local adminIdentifier = "console"
                        
                        if adminSource then
                            adminName = GetPlayerName(adminSource)
                            adminIdentifier = self:getMainIdentifier(adminSource)
                        end

                        webhook:sendEditBanWebhook(result[1].target_name, result[1].identifiers, reason, duration, adminName)
                        
                        -- Get updated ban list after changes
                        self:getActiveBans(function(updatedBans)
                            if adminSource then
                                -- Send the updated list to the client
                                TriggerClientEvent('ban:updateBanList', adminSource, updatedBans)
                                
                                TriggerClientEvent('ban:editSuccess', adminSource, {
                                    targetName = result[1].target_name,
                                    reason = reason,
                                    duration = duration
                                })
                            else
                                logger:info(string.format(config.Messages.banEditSuccess, result[1].target_name))
                            end
                        end)
                    end
                end)
        else
            if adminSource then
                TriggerClientEvent('chat:addMessage', adminSource, {
                    color = {255, 0, 0},
                    multiline = true,
                    args = {"System", config.Messages.notBanned}
                })
            else
                logger:error(config.Messages.notBanned)
            end
        end
    end)
end

function BanModule:setUnbanned(identifier)
    exports.oxmysql:execute('SELECT * FROM ban_system WHERE is_active = 1', {}, function(result)
        if result then
            for _, banData in ipairs(result) do
                local identifiers = json.decode(banData.identifiers)
                if identifiers then
                    for _, id in ipairs(identifiers) do
                        if id == identifier then
                            exports.oxmysql:execute('UPDATE ban_system SET is_active = 0 WHERE id = ?', {banData.id})

                            for _, bannedId in ipairs(identifiers) do
                                self.bans[bannedId] = nil
                            end
                            
                            break
                        end
                    end
                end
            end
        end
    end)
end

function BanModule:insertBanRecord(banid, identifiersJson, targetName, reason, adminName, adminIdentifier, unbanDate, duration)
    exports.oxmysql:execute('INSERT INTO ban_system (ban_id, identifiers, target_name, reason, admin_name, admin_identifier, unban_date, duration) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        {banid, identifiersJson, targetName, reason, adminName, adminIdentifier, unbanDate, duration},
        function(result)
            if result and result.insertId then
                exports.oxmysql:execute('SELECT * FROM ban_system WHERE id = ?', {result.insertId}, function(banData)
                    if banData and banData[1] then
                        local identifiers = json.decode(identifiersJson)
                        if identifiers then
                            for _, id in ipairs(identifiers) do
                                self.bans[id] = banData[1]
                            end
                        end
                    end
                end)
            end
        end)
end

function BanModule:getActiveBans(callback)
    exports.oxmysql:execute('SELECT * FROM ban_system WHERE is_active = ? ORDER BY ban_date DESC', {1}, function(result)
        local bans = {}
        
        if result and #result > 0 then
            for _, banData in ipairs(result) do
                if banData.identifiers then
                    local identifiers = json.decode(banData.identifiers)
                    if identifiers and #identifiers > 0 then
                        banData.identifier = identifiers[1]
                    end
                end
                
                table.insert(bans, banData)
            end
            
            if callback then
                callback(bans)
            end
        else
            if callback then
                callback({})
            end
        end
    end)
end

function BanModule:isAdmin(source)
    if not source or source <= 0 then return true end
    
    if config.AdminOnly then
        for _, group in ipairs(config.AdminGroups) do
            if bridge.hasPermission(source, group) then
                return true
            end
        end
        
        return false
    end
    
    return true
end

function BanModule:getPlayerIdentifiers(source)
    local identifiers = {}
    
    for i = 0, GetNumPlayerIdentifiers(source) - 1 do
        local identifier = GetPlayerIdentifier(source, i)
        identifiers[#identifiers + 1] = identifier
    end
    
    return identifiers
end

function BanModule:getMainIdentifier(source)
    local identifiers = self:getPlayerIdentifiers(source)
    
    for _, idType in ipairs(config.IdentifierPriority) do
        for _, id in ipairs(identifiers) do
            if string.find(id, idType .. ":") then
                return id
            end
        end
    end
    
    return identifiers[1]
end

function BanModule:isTimeFormat(input)
    return string.match(input, "^%d+[smhdwy]$") ~= nil
end

function BanModule:parseDuration(duration)
    local time = tonumber(string.match(duration, "%d+"))
    local unit = string.match(duration, "%a+")
    
    if unit == "m" then
        return time * 60
    elseif unit == "h" then
        return time * 3600
    elseif unit == "d" then
        return time * 86400
    elseif unit == "w" then
        return time * 604800
    elseif unit == "y" then
        return time * 31536000
    else
        return time
    end
end

function BanModule:calculateUnbanDate(duration)
    local durationSeconds = self:parseDuration(duration)
    local unbanTimestamp = os.time() + durationSeconds
    return os.date("!%Y-%m-%d %H:%M:%S", unbanTimestamp)
end

function BanModule:formatTimeLeft(seconds)
    if seconds <= 0 then
        return "now"
    end
    
    local timeTable = {}
    
    local days = math.floor(seconds / 86400)
    if days > 0 then
        table.insert(timeTable, days .. " day" .. (days > 1 and "s" or ""))
        seconds = seconds - (days * 86400)
    end
    
    local hours = math.floor(seconds / 3600)
    if hours > 0 then
        table.insert(timeTable, hours .. " hour" .. (hours > 1 and "s" or ""))
        seconds = seconds - (hours * 3600)
    end
    
    local minutes = math.floor(seconds / 60)
    if minutes > 0 then
        table.insert(timeTable, minutes .. " minute" .. (minutes > 1 and "s" or ""))
        seconds = seconds - (minutes * 60)
    end
    
    if seconds > 0 and #timeTable < 2 then
        table.insert(timeTable, seconds .. " second" .. (seconds > 1 and "s" or ""))
    end
    
    if #timeTable <= 0 then
        return "0 seconds"
    end
    
    if #timeTable == 1 then
        return timeTable[1]
    end
    
    return table.concat(timeTable, ", ", 1, #timeTable - 1) .. " and " .. timeTable[#timeTable]
end

local instance = BanModule.new()
instance:init()

return instance