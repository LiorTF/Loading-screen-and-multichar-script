--[[ lt-startscreen — client utilities ]]

Utils = {}

--- Request & load a model hash, timing out gracefully.
function Utils.loadModel(model)
    if type(model) == 'string' then model = joaat(model) end
    if not IsModelInCdimage(model) then return false end
    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) and timeout < 200 do
        Wait(10); timeout = timeout + 1
    end
    return HasModelLoaded(model)
end

--- Park the local player somewhere hidden, frozen and invisible while the
--- selection UI is up. This keeps the world quiet behind our full-screen menus.
function Utils.prepPlayerForMenu()
    local ped = PlayerPedId()
    local h = Config.Multichar.hiddenCoords
    SetEntityCoordsNoOffset(ped, h.x, h.y, h.z, false, false, false)
    SetEntityHeading(ped, h.w or 0.0)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    SetPlayerControl(PlayerId(), false, 0)
    SetPlayerInvincible(PlayerId(), true)
    SetEntityInvincible(ped, true)
    -- Kill any lingering wanted level / phone / etc.
    ClearPlayerWantedLevel(PlayerId())
    DisplayRadar(false)
end

--- Cinematic still camera behind the menu (subtle — the UI covers it, but
--- this guarantees a clean, non-flickering scene during the hand-off).
local menuCam = nil
function Utils.setupCamera()
    local c = Config.Multichar.camera
    if menuCam then return end
    menuCam = CreateCamWithParams(
        'DEFAULT_SCRIPTED_CAMERA',
        c.cam.x, c.cam.y, c.cam.z,
        0.0, 0.0, 0.0, c.fov, false, 0
    )
    PointCamAtCoord(menuCam, c.point.x, c.point.y, c.point.z)
    SetCamActive(menuCam, true)
    RenderScriptCams(true, false, 0, true, false)
end

function Utils.destroyCamera()
    if menuCam then
        RenderScriptCams(false, false, 0, true, false)
        DestroyCam(menuCam, false)
        menuCam = nil
    end
end

--- Restore full control of the player after spawn is chosen.
function Utils.releasePlayer()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)
    SetPlayerControl(PlayerId(), true, 0)
    SetPlayerInvincible(PlayerId(), false)
    SetEntityInvincible(ped, false)
    DisplayRadar(true)
end
