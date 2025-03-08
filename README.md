# External Ban System for FiveM

![Main Banner](https://i.ibb.co/Y48BjDJC/Medal-9-Kq-Wzn-Yje-T-Photoroom.png)

A comprehensive ban management solution for FiveM servers with a sleek UI, offline banning capabilities, and extensive customization options.

## Features

* **Elegant User Interface**: Modern, responsive design with intuitive controls
* **Real-time Ban Management**: Ban, unban, and edit existing bans with ease
* **Advanced Player Verification**: Detailed connection screens with ban history checks
* **Offline Banning System**: Ban players even when they're not connected
* **Customizable Ban Durations**: From hours to permanent bans with a user-friendly selection system
* **Discord Webhook Integration**: Automatic notifications for all ban actions
* **Multi-identifier Support**: Ban by license, steam, discord, IP, and more
* **Ban Appeal System**: Configurable appeal link and information for banned players
* **Admin Permission System**: Works with ESX, QB-Core, and ACE permissions
* **Detailed Ban Records**: Track ban history and manage all active bans in one place

## Preview

### Banned Player Screen
![Banned Screen](https://r2.e-z.host/50178759-6a77-461c-84d2-9262b3c5465f/w05z6yct.gif)

### Successful Connection Screen
![Non Banned Screen](https://r2.e-z.host/50178759-6a77-461c-84d2-9262b3c5465f/ojpvbmyy.gif)

### Ban Message
![Ban Message](https://i.imgur.com/8UE4vQR.png)

### Admin Interface

#### Main Ban Screen
![Main Screen](https://i.imgur.com/Qa9UApo.png)

#### Offline Ban Screen
![Offline Ban](https://i.imgur.com/OVoJoqc.png)

#### Active Bans List
![Active Bans List](https://i.imgur.com/kVLO2iA.png)

#### Edit Ban Modal
![Edit Ban Modal](https://i.imgur.com/SDXjrH9.png)

## Installation

1. Download the latest release
2. Extract to your server's resources directory
3. Configure the webhook URLs in `secure_config.lua`
4. Add `ensure external_bansystem` to your server.cfg


## Configuration

### Main Configuration (config.lua)

```lua
return {
    Debug = false,
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
            ban = 16711680,      -- Red
            unban = 65280,       -- Green
            edit = 16776960      -- Yellow
        }
    },
    
    Messages = {
        
    },
    
    UI = {
        appealInfo = {
            enabled = true,
            discordLink = "https://discord.gg/yourserver",
            showAppealButton = true,
            message = "If you believe this ban was issued by mistake, you may appeal on our Discord server."
        },
        
        durations = {
            
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

- `/unban [ban_id]` - Unban a player
  - Example: `/unban ABC-123-XYZ`

### Interface

- Press the configured keybind (default: F10) to open the ban menu
- Ban Menu: Select a player and provide reason and duration
- Offline Ban: Enter player identifiers and ban information
- Ban List: View, edit, or unban players from the list

## Framework Support

- ✅ ESX Legacy
- ✅ QB-Core
- ✅ Standalone (ACE Permissions)

## Requirements

- oxmysql
- ESX/QB

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

Need help? Found a bug? Have a feature request? Open an issue or reach out on Discord.