
# External Ban System

![Banner](https://i.ibb.co/Y48BjDJC/Medal-9-Kq-Wzn-Yje-T-Photoroom.png)

## Overview

External Ban System is a comprehensive ban management solution for FiveM servers, offering a modern user interface, powerful ban controls, and extensive customization options. This resource makes it easy for server administrators to manage player bans with advanced features like offline banning, ban history tracking, and Discord webhook integration.

[![Showcase Video]](https://www.youtube.com/watch?v=3o849jRd1G0)
*Click the image above to watch the showcase video*

## Features

- **Elegant User Interface**: Clean, responsive design with intuitive controls
- **Real-time Ban Management**: Ban, unban, and edit existing bans with ease
- **Advanced Player Verification**: Detailed connection screens with ban history checks
- **Offline Banning System**: Ban players even when they're not connected
- **Customizable Ban Durations**: From hours to permanent bans with a user-friendly selection system
- **Discord Webhook Integration**: Automatic notifications for all ban actions
- **Multi-identifier Support**: Ban by license, steam, discord, IP, and more
- **Ban Appeal System**: Configurable appeal link and information for banned players
- **Admin Permission System**: Works with ESX, QB-Core, and ACE permissions
- **Detailed Ban Records**: Track ban history and manage all active bans in one place

## Preview

![Ban Menu](https://i.imgur.com/D7gLdBb.png)
![Ban List](https://i.imgur.com/hjTnv91.png)
![Offline Ban](https://i.imgur.com/NcW72cn.png)

## Installation

1. Download the latest release
2. Extract the folder to your server's resources directory
3. Add `ensure external_bansystem` to your server.cfg
4. Configure the `config.lua` and `secure_config.lua` files
5. Restart your server

## Configuration

### Main Configuration (config.lua)

```lua
return {
    Debug = false,                     -- Enable debug mode
    AdminOnly = true,                  -- Restrict to admins only
    AdminGroups = {"admin", "mod"},    -- Admin groups with permission
    Keybind = "F10",                   -- Keybind to open the ban menu
    
    IdentifierPriority = {            -- Order of identifier priority
        "license",
        "steam",
        "discord",
        "ip"
    },
    
    Commands = {
        ban = "ban",                  -- Ban command
        unban = "unban",              -- Unban command
    },
    
    Webhook = {
        botName = "External Ban System",
        avatarUrl = "https://i.imgur.com/xxxxxxxxx.png", 
        footerText = "External Ban System • Powered by your_server_name",
        footerIcon = "https://i.imgur.com/xxxxxxxxx.png", 
        color = {
            ban = 16711680,      -- Red color for ban webhooks
            unban = 65280,       -- Green color for unban webhooks
            edit = 16776960      -- Yellow color for edit webhooks
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
            enabled = true,
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
```

### Discord Webhook Configuration (secure_config.lua)

```lua
Links = {
    ban = "https://discord.com/api/webhooks/your_webhook_url_for_bans",
    unban = "https://discord.com/api/webhooks/your_webhook_url_for_unbans",
    edit = "https://discord.com/api/webhooks/your_webhook_url_for_edits",
}
```

## Usage

### Commands

- `/ban [id] [duration] [reason]` - Ban a player
  - Example: `/ban 1 7d Griefing`
  - Duration formats: 1h (hour), 1d (day), 1w (week), 1m (month), 1y (year), perm or permanent
  - Omitting duration will result in a permanent ban

- `/unban [ban_id]` - Unban a player
  - Example: `/unban ABC-123-XYZ`

### Interface

- Press the configured keybind (default: F10) to open the ban menu
- Ban Menu: Select a player and provide reason and duration
- Offline Ban: Enter player identifiers and ban information
- Ban List: View, edit, or unban players from the list

## Requirements

- oxmysql
- ESX/QBCore

## License

This project is licensed under the [MIT License](LICENSE)



## Support

If you need help or have suggestions, please open an issue on GitHub or contact me on Discord: kyle337.
