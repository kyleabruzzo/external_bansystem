return {
    Debug = true,
    AdminOnly = true,
    AdminGroups = {"admin", "mod"},
    Keybind = "F10",
    
    IdentifierPriority = {
        "license",
        "steam",
        "discord",
        "ip"
    },
    
    Commands = {
        ban = "ban",
        unban = "unban",
    },
    
    Webhook = {
        botName = "External Ban System",
        avatarUrl = "https://i.imgur.com/xxxxxxxxx.png", 
        footerText = "External Ban System • Powered by your_server_name",
        footerIcon = "https://i.imgur.com/xxxxxxxxx.png", 
        color = {
            ban = 16711680,      
            unban = 65280,       
            edit = 16776960      
        }
    },
    
    Messages = {
        banUsage = "Usage: /ban [id] [duration (optional)] [reason]",
        unbanUsage = "Usage: /unban [ban_id]",
        playerNotFound = "Player not found.",
        identifierError = "Could not find a valid identifier for this player.",
        banned = "You have been banned.\nBan ID: %s\nReason: %s\nBanned by: %s\nBan Date: %s\nDuration: %s",
        unbanSuccess = "%s has been unbanned.",
        banEditSuccess = "Ban for %s has been updated.",
        notBanned = "This identifier is not banned or already unbanned.",
    },
    
    UI = {
        appealInfo = {
            enabled = false,
            discordLink = "https://discord.gg/yourserver",
            showAppealButton = true,
            message = "If you believe this ban was issued by mistake, you may appeal on our Discord server."
        },
        
        durations = {
            {label = "Permanent", value = "5475d"},
            {label = "1 Hour", value = "1h"},
            {label = "6 Hours", value = "6h"},
            {label = "12 Hours", value = "12h"},
            {label = "1 Day", value = "1d"},
            {label = "3 Days", value = "3d"},
            {label = "7 Days", value = "7d"},
            {label = "14 Days", value = "14d"},
            {label = "30 Days", value = "30d"},
            {label = "60 Days", value = "60d"},
            {label = "90 Days", value = "90d"},
            {label = "6 Months", value = "180d"},
            {label = "1 Year", value = "365d"}
        }
    },
}