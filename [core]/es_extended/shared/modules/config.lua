---@param key? string Key pair to get specific value of config
---@return unknown Returns the whole config if no key is passed, or a specific value
function ESX.GetConfig(key)
    if key then
        return Config[key]
    end

    return Config
end
