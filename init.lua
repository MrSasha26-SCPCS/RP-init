local PluginAPI = CS.Akequ.Plugins.PluginAPI
local GameObject = CS.UnityEngine.GameObject

local function getConfigBool(id, default_val)
    local file = io.open("config.ini", "r")

    if file then
        for line in file:lines() do
            local pattern = id .. ":"
            if string.find(line, pattern) then
                if string.find(line, "true") then
                    return true
                else
                    return false
                end
            end
        end             
        file:close()
    end
    return default_val
end

local function getIndex(tab, val)
    for i, value in ipairs(tab) do
        if value == val then
            return i
        end
    end
    return -1
end

local function toTable(g)
    local myTable = {}
    for i = 0, g.Length - 1 do
        table.insert(myTable, g[i])
    end
    return myTable
end

---@class Init:CS.Akequ.Plugins.PluginInitializator
Init = {}

function Init:GlobalInit()            
    PluginAPI.RegisterAdminPanel("AAA", "aaa")

    PluginAPI.RegisterRoomEvent("EZ_Lockroom_event")
    PluginAPI.RegisterRoomEvent("PD_event")
    PluginAPI.RegisterRoomEvent("AWRoom_event")
    PluginAPI.RegisterRoomEvent("EZ_Medibay_event")
    PluginAPI.RegisterRoomEvent("mrs_RoundTimer")
    PluginAPI.RegisterRoomEvent("NewRoundManager")
    PluginAPI.RegisterRoomEvent("NewSupportManager")
    PluginAPI.RegisterRoomEvent("Tips")
    PluginAPI.RegisterRoomEvent("AutoSpawn")
    PluginAPI.RegisterRoomEvent("WaitingPVP")
    PluginAPI.RegisterRoomEvent("SCP173CageBoxSpawner")

    PluginAPI.RegisterRoomEvent("SCPHole")

    PluginAPI.RegisterPlayerClass("TutorialClass", false)
    PluginAPI.RegisterPlayerClass("SerpentsHand", false)
    PluginAPI.RegisterPlayerClass("PVPClass", false)
    PluginAPI.RegisterPlayerClass("ChaosInsurgency", false)
    PluginAPI.RegisterPlayerClass("SCP173", false)

    PluginAPI.RegisterItem("SCP420J", false, CS.ResourcesManager.GetSprite("inv_item_scp420j"))
    PluginAPI.RegisterItem("Cup", false, CS.ResourcesManager.GetSprite("inv_item_cup"))
end

function Init:InitClient()
    self:GlobalInit()

    _G.sprites = {}

    -- Loading resources and registering items
    CS.ScriptHelper.LoadTexture("scp173_cage_box.png", function(texture)
        if texture ~= nil then
            local sprite = CS.UnityEngine.Sprite.Create(texture, CS.UnityEngine.Rect(0, 0, texture.width, texture.height), CS.UnityEngine.Vector2(0, 0)) 
            _G.sprites["scp173_cage_box"] = sprite 
            PluginAPI.RegisterItem("SCP173CageBox", false, sprite)  
        else
            PluginAPI.RegisterItem("SCP173CageBox", false)                
        end
    end)

    -- AdminRoom
    local room_bundle = CS.ScriptHelper.LoadBundle("adminroom")
    if room_bundle then    
        local shader = room_bundle:LoadAsset("shader.shader", typeof(CS.UnityEngine.Shader))
        local room = GameObject.Instantiate(room_bundle:LoadAsset("adminroom.prefab", typeof(GameObject)))
        local mat = room_bundle:LoadAsset("plant.mat", typeof(CS.UnityEngine.Material))

        room.transform.position = CS.UnityEngine.Vector3(1000, -355, 0)

        local meshRenderers = room:GetComponentsInChildren(typeof(CS.UnityEngine.MeshRenderer))
        for i = 0, meshRenderers.Length - 1 do
            local meshRenderer = meshRenderers[i]
            if not meshRenderer.name:find("Plane") then
                meshRenderer.material.shader = CS.UnityEngine.Shader.Find("Universal Render Pipeline/Lit")
            else
                meshRenderer.material = mat
                meshRenderer.material.shader = shader
            end
        end
    end
end

function Init:InitServer()
    self:GlobalInit()

    PluginAPI.RegisterItem("SCP173CageBox", false)                

    -- UpdatedRooms
    if getConfigBool("updated_rooms", false) then        
        PluginAPI.AddPreMapGenerationCallback(function(zones)            
            --Setting PD
            local pdzone = zones[6]
            local pdroom = pdzone.rooms[0]
            pdroom.eventScript = "PD_event"

            --Setting Lockroom and EZ_Medibay
            local ezone = {}
            for i = 0, zones[2].rooms.Length - 1 do
                local room = zones[2].rooms[i]
                if room.roomName == "EZ_Lockroom" then
                    room.spawnOnce = true
                    room.eventScript = "EZ_Lockroom_event"
                    local hcz = toTable(zones[1].rooms)
                    local lcz = toTable(zones[0].rooms)
                    if getIndex(lcz, room) == -1 then
                        table.insert(lcz, room)
                    end
                    if getIndex(hcz, room) == -1 then
                        table.insert(hcz, room)
                    end
                    zones[0].rooms = lcz
                    zones[1].rooms = hcz
                end
                if room.roomName == "EZ_Medibay" then
                    room.eventScript = "EZ_Medibay_event"
                end
                table.insert(ezone, room)
            end
            zones[2].rooms = ezone
            return zones
        end)
    end

    -- AdminRoom
    local room_bundle = CS.ScriptHelper.LoadBundle("adminroom")
    if room_bundle then    
        local room = GameObject.Instantiate(room_bundle:LoadAsset("adminroom.prefab", typeof(GameObject)))
        room.transform.position = CS.UnityEngine.Vector3(1000, -355, 0)
        room.name = "AdminRoom"
    end

    CS.HookManager.Add("onMapGenerationComplete", function(obj)        
        PluginAPI.SpawnNetworkedEvent("NewRoundManager") 
        PluginAPI.SpawnNetworkedEvent("NewSupportManager")   
        PluginAPI.SpawnNetworkedEvent("IntercomLoot")   
        PluginAPI.SpawnNetworkedEvent("HC079Loot")   
        PluginAPI.SpawnNetworkedEvent("AutoSpawn")  
        PluginAPI.SpawnNetworkedEvent("SCP173CageBoxSpawner")  
        if CS.Config.GetBool("updated_rooms", false) then
            PluginAPI.SpawnNetworkedEvent("AWRoom_event")
        end
    end)
    CS.HookManager.Add("onRoundStart", function(obj)
        PluginAPI.SpawnNetworkedEvent("mrs_RoundTimer") 
        PluginAPI.SpawnNetworkedEvent("Tips") 
        PluginAPI.SpawnNetworkedEvent("SCPHole")

        if GameObject.FindObjectsOfType(typeof(CS.Player)).Length < CS.Config.GetInt("start_default_round_minimum_players", 6) then
            PluginAPI.SpawnNetworkedEvent("WaitingPVP")
        end
    end)
end

return Init