Core.CommandPermissions = Config.CommandPermissions or {}

function Core.FilterCommandGroups(groups)
    return (groups and #groups > 0) and groups or { "user" }
end