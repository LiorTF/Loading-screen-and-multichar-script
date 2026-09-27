--[[ lt-startscreen — client spawn finalizer ]]

local lastPosition = nil

-- Capture the last saved position when the spawn screen opens.
local _origOpenSpawn = OpenSpawn
function OpenSpawn(pos)
    lastPosition = pos
    _origOpenSpawn(pos)
end

local function resolveCoords(data)
    if data and data.id == 'last' and lastPosition then
        return vector4(lastPosition.x, lastPosition.y, lastPosition.z, lastPosition.a or 0.0)
    end
    for _, loc in ipairs(Config.Spawn.locations) do
        if loc.id == (data and data.id) then
            return loc.coords
        end
    end
    -- Fallback: first recommended, else first location.
    for _, loc in ipairs(Config.Spawn.locations) do
        if loc.recommended then return loc.coords end
    end
    return Config.Spawn.locations[1] and Config.Spawn.locations[1].coords
end

function FinalizeSpawn(data)
    local coords = resolveCoords(data)
    if not coords then return end

    -- Let the UI play its exit animation, then fade the world in beneath it.
    DoScreenFadeOut(Config.Spawn.fadeOut)
    Wait(Config.Spawn.fadeOut + 50)

    local ped = PlayerPedId()

    -- Ensure the correct model is streamed (in case appearance editor changed it).
    Utils.destroyCamera()

    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(ped, coords.w or coords.a or 0.0)

    -- Stream the world in around us before we reveal it.
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    NewLoadSceneStart(coords.x, coords.y, coords.z, coords.x, coords.y, coords.z, 50.0, 0)
    local t = 0
    while not IsNewLoadSceneLoaded() and t < 150 do Wait(10); t = t + 1 end
    NewLoadSceneStop()

    local ct = 0
    while not HasCollisionLoadedAroundEntity(ped) and ct < 200 do Wait(10); ct = ct + 1 end

    Utils.releasePlayer()

    -- Close the NUI now that the world is ready underneath.
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
    LT.screen = 'ingame'

    Wait(200)
    DoScreenFadeIn(Config.Spawn.fadeIn)

    -- Persist spawn so "Last Location" works next time.
    TriggerServerEvent('lt-startscreen:server:setSpawn', {
        x = coords.x, y = coords.y, z = coords.z, a = coords.w or coords.a or 0.0
    })

    -- Let the rest of your server know selection is fully complete.
    TriggerEvent('lt-startscreen:client:spawned', LT.activeChar)
    TriggerServerEvent('lt-startscreen:server:playerFullyLoaded')

    if Config.Debug then
        print(('^5[lt-startscreen]^7 spawned %s at %s'):format(tostring(LT.activeChar), tostring(data and data.id)))
    end
end
