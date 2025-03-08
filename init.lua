
_G.initializedModules = _G.initializedModules or {}
_G.registeredEvents = _G.registeredEvents or {}

function MarkInitialized(moduleName)
    _G.initializedModules[moduleName] = true
end

function IsInitialized(moduleName)
    return _G.initializedModules[moduleName] == true
end

function RegisterEventOnce(eventName, handler)
    if _G.registeredEvents[eventName] then
        return
    end
    
    _G.registeredEvents[eventName] = true
    RegisterNetEvent(eventName)
    AddEventHandler(eventName, handler)
end

local logger = require("modules.utility.shared.logger")

if IsDuplicityVersion() then
    CreateThread(function()
        local bridge = require("modules.utility.bridge.server")
        logger:info("Initializing Server Side...")
        
        local detectedFramework = bridge.getFrameworkName()
        if not detectedFramework then
            logger:error("No framework detected")
            return
        end
        
        logger:success("Framework detected:", string.upper(detectedFramework))
        
        local webhook = require("modules.webhook.server")
        local banModule = require("modules.ban.server")
        banModule:init()

        local VersionChecker = require("modules.utility.shared.versioncheck")
        VersionChecker.checkVersion()
        
        logger:success("Server Side initialized successfully")
    end)
else
    CreateThread(function()
        local bridge = require("modules.utility.bridge.client")
        local interface = require("modules.interface.client")
        local banModule = require("modules.ban.client")
        banModule:init()
        
        logger:success("Client initialized successfully")
    end)
end