local logger = require("modules.utility.shared.logger")
local currentVersion = GetResourceMetadata(GetCurrentResourceName(), 'version', 0)

local function checkVersion()
    PerformHttpRequest("https://api.github.com/repos/kyleabruzzo/external_bansystem/releases/latest", function(err, text, headers)
        if err ~= 200 then
            logger:error("Failed to check for updates")
            return
        end

        local data = json.decode(text)
        if not data then return end

        local latestVersion = data.name:gsub("v", "")
        if latestVersion ~= currentVersion then
            logger:versionCheckerError("^3--------------------------^7")
            logger:versionCheckerError("Ban System is ^1outdated^7!")
            logger:versionCheckerError("Current Version: ^1" .. currentVersion .. "^7")
            logger:versionCheckerError("Latest Version: ^2" .. latestVersion .. "^7")
            logger:versionCheckerError("Download the new version from: ^5" .. data.html_url .. "^7")
            logger:versionCheckerError("^3--------------------------^7")
        else
            logger:versionCheckerSuccess("Ban System is up to date! (Version: " .. currentVersion .. ")")
        end
    end)
end

return {
    checkVersion = checkVersion
}