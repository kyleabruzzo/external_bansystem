local logger = require("modules.utility.shared.logger")
local config = require("shared.config")
if IsInitialized('server_bridge') then
    return require("_loadedModules")['modules.utility.bridge.server']
end

local bridge = {}
bridge.framework = nil
bridge.frameworkObject = nil

local rateLimiters = {}
local rateLimiterLastCleanup = os.time()
local spamTracker = {}
local identifierSpamMap = {}
local lastProcessedRequests = {}


function bridge.setupDatabase()
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `banSys_security` (
            `identifier` VARCHAR(100) NOT NULL PRIMARY KEY,
            `count` INT NOT NULL DEFAULT 0,
            `lastOffense` INT NOT NULL DEFAULT 0,
            `warnings` TEXT NOT NULL,
            `createdAt` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `updatedAt` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
    ]], {}, function()
        logger:success("Security database setup complete")
    end)
end

function bridge.loadSpamHistory()
    local result = {}
    bridge.setupDatabase()

    MySQL.Async.fetchAll("SELECT * FROM `banSys_security`", {}, function(records)
        if records and #records > 0 then
            for _, record in ipairs(records) do
                local warnings = {}
                if record.warnings and record.warnings ~= "" then
                    local success, parsed = pcall(json.decode, record.warnings)
                    if success and parsed then
                        warnings = parsed
                    end
                end

                result[record.identifier] = {
                    count = tonumber(record.count) or 0,
                    lastOffense = tonumber(record.lastOffense) or os.time(),
                    warnings = warnings,
                    sources = {}
                }
            end
        end
    end)

    return result
end

function bridge.saveSpamHistory()
    for identifier, data in pairs(spamTracker) do
        if type(identifier) == "string" and identifier:match("license:") then
            if data.count and data.count > 0 then
                local warningsJson = "{}"
                if data.warnings then
                    local success, jsonStr = pcall(json.encode, data.warnings)
                    if success then
                        warningsJson = jsonStr
                    end
                end

                MySQL.Async.execute([[
                    REPLACE INTO `banSys_security`
                    (identifier, count, lastOffense, warnings)
                    VALUES (?, ?, ?, ?)
                ]], {
                    identifier,
                    data.count or 0,
                    data.lastOffense or os.time(),
                    warningsJson
                })
            end
        end
    end
end

function bridge.cleanupOldViolations()
    local currentTime = os.time()
    local cutoffTime = currentTime - (config.CleanupConfig.inactivityPeriod * 3600)

    MySQL.Async.execute([[
        DELETE FROM `banSys_security`
        WHERE lastOffense < ? AND count <= ?
    ]], {
        cutoffTime,
        config.AbusePenalties.dropThreshold - 1
    }, function(rowsChanged)
        if rowsChanged and rowsChanged > 0 then
            logger:info("Cleaned up " .. rowsChanged .. " old security records")
        end
    end)

    MySQL.Async.execute([[
        UPDATE `banSys_security`
        SET count = 0, warnings = '{}'
        WHERE lastOffense < ? AND count >= ?
    ]], {
        cutoffTime,
        config.AbusePenalties.dropThreshold
    }, function(rowsChanged)
        if rowsChanged and rowsChanged > 0 then
            logger:info("Reset " .. rowsChanged .. " old high-count security records")
        end
    end)
end

function bridge.getStableIdentifier(source)
    if not source or source <= 0 then return nil end

    for i = 0, GetNumPlayerIdentifiers(source) - 1 do
        local identifier = GetPlayerIdentifier(source, i)
        if identifier and string.find(identifier, "license:") then
            return identifier
        end
    end

    for i = 0, GetNumPlayerIdentifiers(source) - 1 do
        local identifier = GetPlayerIdentifier(source, i)
        if identifier and string.find(identifier, "steam:") then
            return identifier
        end
    end

    for i = 0, GetNumPlayerIdentifiers(source) - 1 do
        local identifier = GetPlayerIdentifier(source, i)
        if identifier then
            return identifier
        end
    end

    return "ip:" .. GetPlayerEndpoint(source)
end

function bridge.isRateLimited(source, action)
    if not source or source <= 0 then return false end

    local currentTime = os.time()
    local sourceStr = tostring(source)
    local config = config.RateLimits[action] or { maxRequests = 3, timeWindow = 3 }

    local stableIdentifier = bridge.getStableIdentifier(source)
    if not stableIdentifier then return false end

    identifierSpamMap[sourceStr] = stableIdentifier

    if currentTime - rateLimiterLastCleanup > 30 then
        bridge.cleanupRateLimiters()
        rateLimiterLastCleanup = currentTime
    end

    local requestId = stableIdentifier .. "_" .. action .. "_" .. currentTime .. "_" .. math.random(1000000)

    if not rateLimiters[sourceStr] then
        rateLimiters[sourceStr] = {}
    end

    if not rateLimiters[sourceStr][action] then
        rateLimiters[sourceStr][action] = {
            requests = {},
            lastWarning = 0
        }
    end

    local limiter = rateLimiters[sourceStr][action]

    local i = 1
    while i <= #limiter.requests do
        if (currentTime - limiter.requests[i]) > config.timeWindow then
            table.remove(limiter.requests, i)
        else
            i = i + 1
        end
    end

    table.insert(limiter.requests, currentTime)

    if #limiter.requests > config.maxRequests then
        if lastProcessedRequests[requestId] then
            return true
        end

        lastProcessedRequests[requestId] = currentTime

        if (currentTime - limiter.lastWarning) > 2 then
            logger:warn(string.format("Rate limit exceeded: source=%s, action=%s, requests=%d/%d in %ds",
                source, action, #limiter.requests, config.maxRequests, config.timeWindow))
            limiter.lastWarning = currentTime
        end

        if not spamTracker[stableIdentifier] then
            spamTracker[stableIdentifier] = {
                count = 0,
                lastOffense = currentTime,
                warnings = {},
                sources = {}
            }
        end

        if not spamTracker[stableIdentifier].warnings then
            spamTracker[stableIdentifier].warnings = {}
        end

        if not spamTracker[stableIdentifier].warnings[action] then
            spamTracker[stableIdentifier].warnings[action] = 0
        end

        local lastAction = spamTracker[stableIdentifier].lastAction or {}
        if not lastAction[action] or (currentTime - lastAction[action]) > config.timeWindow then
            spamTracker[stableIdentifier].warnings[action] = spamTracker[stableIdentifier].warnings[action] + 1
            spamTracker[stableIdentifier].count = spamTracker[stableIdentifier].count + 1

            if not spamTracker[stableIdentifier].lastAction then
                spamTracker[stableIdentifier].lastAction = {}
            end
            spamTracker[stableIdentifier].lastAction[action] = currentTime
        end

        for id, time in pairs(lastProcessedRequests) do
            if currentTime - time > 60 then
                lastProcessedRequests[id] = nil
            end
        end

        spamTracker[stableIdentifier].lastOffense = currentTime

        logger:warn(string.format("Player %s (ID: %s, Identifier: %s) has %d violations",
            GetPlayerName(source) or "Unknown", source, stableIdentifier, spamTracker[stableIdentifier].count))

        if spamTracker[stableIdentifier].count >= config.AbusePenalties.banThreshold and GetPlayerName(source) then
            if GetPlayerPing(source) > 0 then
                logger:warn(string.format(
                    "BANNING player %s (ID: %s, Identifier: %s) - %d violations exceeded threshold of %d",
                    GetPlayerName(source), source, stableIdentifier,
                    spamTracker[stableIdentifier].count, config.AbusePenalties.banThreshold))

                local banModule = require("modules.ban.server")
                banModule:banPlayer(
                    0,
                    source,
                    "Automatic ban for API spam - " .. spamTracker[stableIdentifier].count .. " violations",
                    config.AbusePenalties.banDuration
                )

                logger:info("Ban request sent for player ID " .. source)
            end

            bridge.saveSpamHistory()
        elseif spamTracker[stableIdentifier].count >= config.AbusePenalties.dropThreshold then
            if GetPlayerName(source) and GetPlayerPing(source) > 0 then
                logger:warn(string.format("Dropping player %s (ID: %s, Identifier: %s) for API spam: %d violations",
                    GetPlayerName(source), source, stableIdentifier, spamTracker[stableIdentifier].count))

                DropPlayer(source, "Rate limited - excessive API spam detected")
            end

            bridge.saveSpamHistory()
        end

        table.remove(limiter.requests, 1)
        return true
    end

    return false
end

function bridge.cleanupRateLimiters()
    local currentTime = os.time()
    local removed = 0

    for sourceStr, actions in pairs(rateLimiters) do
        local removeSource = true

        for action, data in pairs(actions) do
            local i = 1
            while i <= #data.requests do
                if (currentTime - data.requests[i]) > 300 then
                    table.remove(data.requests, i)
                else
                    i = i + 1
                end
            end

            if #data.requests > 0 then
                removeSource = false
            end
        end

        if removeSource then
            if identifierSpamMap[sourceStr] then
                identifierSpamMap[sourceStr] = nil
            end

            rateLimiters[sourceStr] = nil
            removed = removed + 1
        end
    end
end

function bridge.securityLog(source, action, result, details)
    local playerName = GetPlayerName(source) or "Unknown"
    local logMsg = string.format("[SECURITY] %s (ID: %s) - Action: %s - Result: %s",
        playerName, source, action, result)

    if details then
        logMsg = logMsg .. " - Details: " .. details
    end

    logger:warn(logMsg)
end

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

    spamTracker = bridge.loadSpamHistory()
end

function bridge.hasPermission(source, permission)
    if not source or source <= 0 then return true end
    if not permission or type(permission) ~= "string" then return false end

    local player = bridge.getPlayer(source)
    if not player then return false end

    local result = false

    if bridge.framework == 'esx' then
        result = player.getGroup() == permission
        logger:info("ESX permission check for player:", player.identifier, "Permission:", tostring(permission), "Result:",
            result)
    elseif bridge.framework == 'qbcore' then
        result = bridge.frameworkObject.Functions.HasPermission(source, permission)
        logger:info("QB-Core permission check for source:", source, "Permission:", tostring(permission), "Result:",
            result)
    else
        result = IsPlayerAceAllowed(source, "group." .. permission)
        logger:info("Ace permission check for source:", source, "Permission:", tostring(permission), "Result:", result)
    end

    return result
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

function bridge.getFrameworkName()
    if not bridge.framework then bridge.setup() end
    return bridge.framework
end

function bridge.getAllPlayers()
    if not bridge.framework then bridge.setup() end
    local players = {}

    if bridge.framework == 'esx' then
        local esxPlayers = bridge.frameworkObject.GetPlayers()
        for _, playerId in ipairs(esxPlayers) do
            local player = bridge.frameworkObject.GetPlayerFromId(playerId)
            if player then
                table.insert(players, {
                    id = playerId,
                    name = GetPlayerName(playerId),
                    identifier = player.identifier
                })
            else
                table.insert(players, {
                    id = playerId,
                    name = GetPlayerName(playerId)
                })
            end
        end
    elseif bridge.framework == 'qbcore' then
        local qbPlayers = bridge.frameworkObject.Functions.GetPlayers()
        for _, playerId in ipairs(qbPlayers) do
            local player = bridge.frameworkObject.Functions.GetPlayer(playerId)
            if player then
                table.insert(players, {
                    id = playerId,
                    name = GetPlayerName(playerId),
                    identifier = player.PlayerData.citizenid
                })
            else
                table.insert(players, {
                    id = playerId,
                    name = GetPlayerName(playerId)
                })
            end
        end
    else
        for _, playerId in ipairs(GetPlayers()) do
            table.insert(players, {
                id = tonumber(playerId),
                name = GetPlayerName(playerId)
            })
        end
    end

    return players
end

bridge.setup()

CreateThread(function()
    while true do
        Wait(300000)
        bridge.saveSpamHistory()
    end
end)

CreateThread(function()
    while true do
        bridge.cleanupOldViolations()
        Wait(config.CleanupConfig.runInterval * 3600 * 1000)
    end
end)

if lib then
    lib.callback.register('bridge:hasPermission', function(source, permx)
        if bridge.isRateLimited(source, 'hasPermission') then
            bridge.securityLog(source, "bridge:hasPermission", "DENIED (Rate Limited)", "Permission: " .. tostring(permx))
            return false
        end

        local result = bridge.hasPermission(source, permx)

        local isAdminGroup = false
        for _, group in ipairs(config.AdminGroups) do
            if permx == group then
                isAdminGroup = true
                break
            end
        end

        if isAdminGroup then
            bridge.securityLog(source, "bridge:hasPermission", result and "GRANTED" or "DENIED",
                "Permission: " .. tostring(permx))
        end

        return result
    end)

    lib.callback.register('bridge:getAllPlayers', function(source)
        local isAdmin = false
        for _, group in ipairs(config.AdminGroups) do
            if bridge.hasPermission(source, group) then
                isAdmin = true
                break
            end
        end

        if not isAdmin then
            bridge.securityLog(source, "bridge:getAllPlayers", "DENIED (Not Admin)")
            return {}
        end

        if bridge.isRateLimited(source, 'getAllPlayers') then
            bridge.securityLog(source, "bridge:getAllPlayers", "DENIED (Rate Limited)")
            return {}
        end

        bridge.securityLog(source, "bridge:getAllPlayers", "GRANTED")
        return bridge.getAllPlayers()
    end)

    AddEventHandler('playerDropped', function()
        bridge.saveSpamHistory()
    end)

    AddEventHandler('onResourceStop', function(resourceName)
        if resourceName == GetCurrentResourceName() then
            bridge.saveSpamHistory()
        end
    end)
end

MarkInitialized('server_bridge')
return bridge
