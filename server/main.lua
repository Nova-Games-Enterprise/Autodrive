-- Recovery preview: deliberately no network installation handlers and no inventory
-- writes. A disabled endpoint is preferable to a fail-open economy operation.
-- Paid installs return only after authoritative transactions/persistence are tested.
local valid, reason = NGEAutodrive.Core.validate(Config)
if not valid then
    print('[nge_autodrive] Disabled: ' .. reason)
    return
end

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    print('[nge_autodrive] 2.0.0-dev.1: factory profiles only; paid installs unavailable.')
    print('[nge_autodrive] Experimental recovery preview; in-game acceptance is pending.')
end)

RegisterCommand('nge_autodrive_status', function()
    print('[nge_autodrive] factory-only preview; no paid installation or module database.')
end, true)
