local function runStaticPlayerMethod(src, method, ...)
    local xPlayer = ESX.Players[src]
    if not xPlayer then
        return
    end

    if not ESX.IsFunctionReference(xPlayer[method]) then
        error(("Attempted to call invalid method on playerId %s: %s"):format(src, method))
    end

    return xPlayer[method](...)
end
exports("RunStaticPlayerMethod", runStaticPlayerMethod)
