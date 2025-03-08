local logger = require("modules.utility.shared.logger")
local config = require("shared.config")

if IsInitialized('webhook') then
    return require("_loadedModules")['modules.webhook.server']
end

local Webhook = {
    sentWebhooks = {}
}

local WEBHOOK_COOLDOWN = 3
local ERROR_MESSAGES = {
    [400] = "Bad Request - The request was improperly formatted or contained invalid parameters",
    [401] = "Unauthorized - Invalid webhook token",
    [403] = "Forbidden - Missing permissions to access this webhook",
    [404] = "Not Found - Webhook URL doesn't exist",
    [429] = "Too Many Requests - Rate limited by Discord",
    [500] = "Internal Server Error - Discord is having issues",
    [502] = "Bad Gateway - Discord is having issues",
    [503] = "Service Unavailable - Discord is temporarily down",
    [504] = "Gateway Timeout - Discord request timed out"
}

function Webhook:init()
    if not config.Webhook then
        logger:warn("Webhook configuration missing in config file")
        return false
    end
    
    logger:info("Webhook module initialized successfully")
    MarkInitialized('webhook')
    return true
end

local function generateWebhookId(type, identifier, timestamp)
    return string.format("%s_%s_%d", type, identifier, timestamp)
end

local function wasRecentlySent(webhookId)
    local currentTime = os.time()
    if Webhook.sentWebhooks[webhookId] and (currentTime - Webhook.sentWebhooks[webhookId] < WEBHOOK_COOLDOWN) then
        return true
    end
    Webhook.sentWebhooks[webhookId] = currentTime
    return false
end

local function formatIdentifierFields(identifiersJson)
    local identifiers = type(identifiersJson) == "string" and json.decode(identifiersJson) or identifiersJson or {}
    local identifierFields = {}
    
    for i, identifier in ipairs(identifiers) do
        local idType = identifier:match("^([^:]+)")
        local idValue = identifier:match("^[^:]+:(.+)")
        
        if idType and idValue then
            local label = idType:upper()
            if i == 1 then 
                label = "Main Identifier (" .. idType:upper() .. ")"
            end
            
            table.insert(identifierFields, {
                name = label,
                value = "```" .. idValue .. "```",
                inline = false
            })
        end
    end
    
    return identifierFields
end

---@param banID string Unique ban identifier
---@param playerName string Name of the banned player
---@param identifiersJson string|table JSON string or table of player identifiers
---@param reason string Reason for the ban
---@param duration string|nil Duration of the ban (nil for permanent)
---@param admin string Name of the admin who issued the ban
function Webhook:sendBanWebhook(banID, playerName, identifiersJson, reason, duration, admin)
    if not Links.ban then 
        logger:info("Ban webhook URL not configured")
        return false 
    end
    
    local webhookId = generateWebhookId("ban", banID, os.time())
    if wasRecentlySent(webhookId) then
        logger:info("Prevented duplicate ban webhook for: " .. banID)
        return false
    end

    local durationText = duration or "Permanent"
    local color = config.Webhook.color and config.Webhook.color.ban or 15158332

    local identifierFields = formatIdentifierFields(identifiersJson)

    local fields = {
        {
            name = "📋 Ban ID",
            value = "```" .. banID .. "```",
            inline = true
        },
        {
            name = "👤 Player",
            value = playerName,
            inline = true
        },
        {
            name = "👮 Admin",
            value = admin,
            inline = true
        },
        {
            name = "⏱️ Duration",
            value = durationText,
            inline = true
        },
        {
            name = "📅 Ban Date",
            value = os.date("%Y-%m-%d %H:%M:%S"),
            inline = true
        },
        {
            name = "❓ Reason",
            value = reason,
            inline = false
        }
    }
    
    for _, field in ipairs(identifierFields) do
        table.insert(fields, field)
    end
    
    local message = {
        username = config.Webhook.botName or "Ban System",
        avatar_url = config.Webhook.avatarUrl,
        embeds = {
            {
                title = "🚫 Player Banned",
                color = color,
                description = "A player has been banned from the server.",
                fields = fields,
                footer = {
                    text = config.Webhook.footerText or "External Ban System • " .. os.date("%Y-%m-%d %H:%M:%S"),
                    icon_url = config.Webhook.footerIcon
                }
            }
        }
    }

    return self:sendToDiscord(Links.ban, message)
end

---@param banId string Unique ban identifier
---@param playerName string Name of the unbanned player
---@param identifiersJson string|table JSON string or table of player identifiers
---@param admin string Name of the admin who issued the unban
function Webhook:sendUnbanWebhook(banId, playerName, identifiersJson, admin)
    if not Links.unban then 
        logger:info("Unban webhook URL not configured")
        return false 
    end
    
    local webhookId = generateWebhookId("unban", banId, os.time())
    if wasRecentlySent(webhookId) then
        logger:info("Prevented duplicate unban webhook for: " .. banId)
        return false
    end

    local color = config.Webhook.color and config.Webhook.color.unban or 5763719

    local identifierFields = formatIdentifierFields(identifiersJson)

    local fields = {
        {
            name = "📋 Ban ID",
            value = "```" .. banId .. "```",
            inline = true
        },
        {
            name = "👤 Player",
            value = playerName,
            inline = true
        },
        {
            name = "👮 Admin",
            value = admin,
            inline = true
        },
        {
            name = "📅 Unban Date",
            value = os.date("%Y-%m-%d %H:%M:%S"),
            inline = true
        }
    }
    
    for _, field in ipairs(identifierFields) do
        table.insert(fields, field)
    end
    
    local message = {
        username = config.Webhook.botName or "Ban System",
        avatar_url = config.Webhook.avatarUrl,
        embeds = {
            {
                title = "✅ Player Unbanned",
                color = color,
                description = "A player has been unbanned from the server.",
                fields = fields,
                footer = {
                    text = config.Webhook.footerText or "External Ban System • " .. os.date("%Y-%m-%d %H:%M:%S"),
                    icon_url = config.Webhook.footerIcon
                }
            }
        }
    }
    
    return self:sendToDiscord(Links.unban, message)
end

---@param playerName string Name of the player whose ban was edited
---@param identifiersJson string|table JSON string or table of player identifiers
---@param reason string New reason for the ban
---@param duration string|nil New duration of the ban (nil for permanent)
---@param admin string Name of the admin who edited the ban
function Webhook:sendEditBanWebhook(playerName, identifiersJson, reason, duration, admin)
    if not Links.edit then 
        logger:info("Edit ban webhook URL not configured")
        return false 
    end

    local webhookId = generateWebhookId("edit", playerName, os.time())
    if wasRecentlySent(webhookId) then
        logger:info("Prevented duplicate edit webhook for: " .. playerName)
        return false
    end
    
    local durationText = duration or "Permanent"
    local color = config.Webhook.color and config.Webhook.color.edit or 3447003
    local identifierFields = formatIdentifierFields(identifiersJson)

    local fields = {
        {
            name = "👤 Player",
            value = playerName,
            inline = true
        },
        {
            name = "👮 Admin",
            value = admin,
            inline = true
        },
        {
            name = "⏱️ New Duration",
            value = durationText,
            inline = true
        },
        {
            name = "📅 Edit Date",
            value = os.date("%Y-%m-%d %H:%M:%S"),
            inline = true
        },
        {
            name = "❓ New Reason",
            value = reason,
            inline = false
        }
    }
    
    for _, field in ipairs(identifierFields) do
        table.insert(fields, field)
    end
    
    local message = {
        username = config.Webhook.botName or "Ban System",
        avatar_url = config.Webhook.avatarUrl,
        embeds = {
            {
                title = "📝 Ban Updated",
                color = color,
                description = "A player's ban has been updated.",
                fields = fields,
                footer = {
                    text = config.Webhook.footerText or "External Ban System • " .. os.date("%Y-%m-%d %H:%M:%S"),
                    icon_url = config.Webhook.footerIcon
                }
            }
        }
    }

    return self:sendToDiscord(Links.edit, message)
end

function Webhook:sendToDiscord(url, message)
    if not url or not url:match("^https://") then
        logger:error("Invalid webhook URL format. Must start with https://")
        return false
    end
    
    PerformHttpRequest(url, function(err, text, headers) 
        if err == 200 or err == 201 or err == 204 then
            return true
        else
            local errorDesc = ERROR_MESSAGES[err] or "Unknown error"
            logger:error("Failed to send Discord webhook " .. err .. " (" .. errorDesc .. ")")
            return false
        end
    end, 'POST', json.encode(message), { ['Content-Type'] = 'application/json' })
    
    return true
end

Webhook:init()
return Webhook