function ESX.OpenContext(...)
    return Core.IsResourceFound("esx_context") and exports["esx_context"]:Open(...)
end

function ESX.PreviewContext(...)
    return Core.IsResourceFound("esx_context") and exports["esx_context"]:Preview(...)
end

function ESX.CloseContext(...)
    return Core.IsResourceFound("esx_context") and exports["esx_context"]:Close(...)
end

function ESX.RefreshContext(...)
    return Core.IsResourceFound("esx_context") and exports["esx_context"]:Refresh(...)
end
