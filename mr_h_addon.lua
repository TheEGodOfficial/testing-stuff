-- Mr H addon: customized DOORS edition of the user-supplied Tplay addon v2.4.0.
-- Original feature implementations and supporting controls: tplaygd.
-- Slide bypass discovery credited by the original source to @nahhthatscrazy.
-- Mr H changes: identity/icon, Drawer ESP, speed range and Auto Floor modes.
-- Requires full mspaint; install in mspaint/addons. Not a standalone script.
-- Original extra DOORS controls are retained because features share dependencies.
local ADDON_CONFIG = {
	IncludeAddedFeatures = false, -- includes features that were officially added by mspaint devs
	SeparateTabForAddon = true, -- creates a separate tab named Tplay's Addon in mspaint window (btw because of this configs will properly load toggles and keypickers values in Tplay's Addon)
	AltFeatures = false, -- creates features that already exists in mspaint, but they coded differently (can be more optimized than mspaint features)
	Debug = false,
}

-- config won't change unless you unload mspaint or just modify getgenv()._MRH_ADDON_CONFIG
ADDON_CONFIG = getgenv()._MRH_ADDON_CONFIG or ADDON_CONFIG
getgenv()._MRH_ADDON_CONFIG = ADDON_CONFIG

function log(...)
	if ADDON_CONFIG.Debug then
		local text = table.concat({...}, " ")
		Library:Notify({
			Title = "Tplay's Addon [Debug]",
			Description = text,
			Time = math.clamp(#text/10, 2, 10)
		})
	end
end

function logprint(...)
	if ADDON_CONFIG.Debug then
		print(...)
	end
end

local Info, Variables, prefix, loaded = {}, {}, "", false

Info.AddonName = 'MrHAddon'
Info.AddonTitle = "Mr H addon"
Info.AddonVersion = '1.0.0'

Info.AddonFullTitle = `{Info.AddonTitle} ({Info.AddonVersion})`

mspaint.AddonInfo = {
	Name = Info.AddonName,
	Title = Info.AddonTitle,
	Game = "doors/doors"
}

-- Fail before installing hooks when loaded in the lightweight viewer.
if not Library or not Library.Toggles or not Library.Toggles.DoorReach
    or not Library.Toggles.InfItems or not Library.Toggles.EnableSpeedHack
    or not Library.Toggles.AntiDupe then
    error("Mr H addon requires full mspaint (DoorReach, InfItems, EnableSpeedHack, AntiDupe). Install in mspaint/addons; the addon viewer does not supply these features.")
end
if game.PlaceId == 6516141723 or game.GameId ~= 2440500124 then
    error("Mr H addon: load inside a DOORS run.")
end

prefix = ADDON_CONFIG.SeparateTabForAddon and Info.AddonName:lower().."_" or ""

if getgenv()._MRH_ADDON_VALUES then
	getgenv()._MRH_ADDON_VALUES.Reload.Value = true
	if getgenv()._MRH_ADDON_VALUES.Loaded.Value then
		getgenv()._MRH_ADDON_VALUES.Loaded:GetPropertyChangedSignal("Value"):Wait()
	end
end

--wow its 'missing' function from infinite yield
function func(t, f, fallback)
	if type(f) == t then return f end
	return fallback
end

function GetFunction(fn: string, e: boolean, fs: Instance): (any) -> any
	local success, result = pcall(function()
		local result = filtergc("function", {
			Name = fn,
			IgnoreExecutor = not e,
		}, true)
		if typeof(result) == "table" and typeof(fs) == "Instance" and fs:IsA("Script") then
			for _, func in result do
				local info = debug.getinfo(func)
				if func.short_src == fs:GetFullName() then
					return func
				end
			end
		end
		return result
	end)
	return success and result
end

local oldestmethods = {}

setupvalue = func("function", debug.setupvalue or setupvalue)
readfile = func("function", readfile, function() return "" end)
writefile = func("function", writefile, function() end)
delfile = func("function", delfile, function() end)
isfile = func("function", isfile, function() end)
makefolder = func("function", makefolder, function() end)
listfiles = func("function", listfiles, function() return {} end)
cloneref = func("function", cloneref, function(...) return ... end)
isfunctionhooked = func("function", isfunctionhooked, function(...) return end)
getrawmetatable = func("function", getrawmetatable or get_raw_metatable, function(...) return end)
setreadonly = func("function", setreadonly or set_read_only)
getnamecallmethod = func("function", getnamecallmethod or get_namecall_method)
checkcaller = func("function", checkcaller or check_caller, function(...) return end)
restoremetamethod = func("function", restoremetamethod or restore_meta_method, getrawmetatable(game) and setreadonly and function(object, method)
	local oldestmethod = oldestmethods[object] and oldestmethods[object][method]
	if oldestmethod then
		local metatable = getrawmetatable(object)
		setreadonly(metatable, false)
		metatable[method] = oldestmethod
		setreadonly(metatable, true)
		oldestmethods[object][method] = nil
	end
end)
_hookmetamethod = func("function", hookmetamethod or hook_meta_method, getrawmetatable(game) and setreadonly and function(object, method, func)
	local metatable = getrawmetatable(object)
	local oldmethod = metatable[method]
	setreadonly(metatable, false)
	metatable[method] = func
	setreadonly(metatable, true)
	return oldmethod
end)

hookmetamethod = _hookmetamethod and function(object: Object, method: string, func: (any) -> any)
	local result = _hookmetamethod(object, method, func)
	if result and not (oldestmethods[object] and oldestmethods[object][method]) then
		oldestmethods[object] = oldestmethods[object] or {}
		oldestmethods[object][method] = result
	end
	return result
end

isnetworkowner = func("function", isnetworkowner, gethiddenproperty and function(part)
    local val = gethiddenproperty(part, "NetworkOwnerV3")
    return val == -1 or val == 4
end)

local function restoremetamethods()
	if not hookmetamethod then
		oldestmethods = nil
		return
	end
	for object, methods in oldestmethods do
		for methodName, method in methods do
			pcall(restoremetamethod, object, methodName)
		end
	end
	oldestmethods = nil
end

Services = setmetatable({}, {
	__index = function(self, name)
		return cloneref(game:GetService(name))
	end
})

function genName()
	local str = ""
	for _ = 1,64 do
		str ..= string.char(math.random(33,126))
	end
	return str
end

local Toggles = {}
local KeyPickers = {}

local ReloadSignals
if debug.setinfo then
	if getgenv()._MRH_ADDON_VALUES then
		for _, bool in getgenv()._MRH_ADDON_VALUES do
			bool:Destroy()
		end
		getgenv()._MRH_ADDON_VALUES = nil
	end
	getgenv()._MRH_ADDON_VALUES = {
		Loaded = Instance.new("BoolValue"),
		Reload = Instance.new("BoolValue")
	}
	getgenv()._MRH_ADDON_VALUES.Loaded.Value = true
	ReloadSignals = {}
end

local function destroyUnloadSignal(name)
	for index, func in Library.UnloadSignals do
		if debug.getinfo(func).name == name then
			table.remove(Library.UnloadSignals, index)
			break
		end
	end
end

reloadConnection = getgenv()._MRH_ADDON_VALUES and getgenv()._MRH_ADDON_VALUES.Reload:GetPropertyChangedSignal("Value"):Connect(function()
	if getgenv()._MRH_ADDON_VALUES.Reload.Value then
		reloadConnection:Disconnect()
		for name, reloadFunc in ReloadSignals do
			destroyUnloadSignal(name)
			local success, err = pcall(reloadFunc, true)
			if not success then
				Library:Notify({
					Title = 'wow something went wrong while reloading',
					Description = err,
					Time = 10
				})
			end
		end
		ReloadSignals = nil
		if ADDON_CONFIG.SeparateTabForAddon then
			for _, picker in KeyPickers do
				if picker.Destroy then
					picker:Destroy()
				end
			end
			for _, toggle in Toggles do
				if toggle.Destroy then
					toggle:Destroy()
				end
			end
		end
		task.wait(.1)
		getgenv()._MRH_ADDON_VALUES.Loaded.Value = false
	end
end)

Library:OnUnload(function()
	if ReloadSignals then
		ReloadSignals = nil
	else
		return -- the addon was reloaded, don't try to unload using this function
	end
	if getgenv()._MRH_ADDON_VALUES then
		for _, bool in getgenv()._MRH_ADDON_VALUES do
			bool:Destroy()
		end
		getgenv()._MRH_ADDON_VALUES = nil
	end
	if getgenv()._MRH_ADDON_CONFIG then
		getgenv()._MRH_ADDON_CONFIG = nil
	end
end)

function OnUnload(func: (WasReloaded: boolean?) -> ()): ()
	if debug.setinfo then
		local funcName = genName()
		debug.setinfo(func, {name = funcName})
		Library:OnUnload(func)
		ReloadSignals[funcName] = func
	else
		Library:OnUnload(func)
	end
end

OnUnload(function()
	loaded = false
end)

local tpath = "mspaint/"..Info.AddonName
local addon = {
	makefolder = function(path: string): ()
		makefolder(`{tpath}/{path}`)
	end,
	listfiles = function(path: string): {string}
		return listfiles(`{tpath}/{path}`)
	end,
	readfile = function(path: string): string
		return readfile(`{tpath}/{path}`)
	end,
	writefile = function(path: string, str: string): ()
		writefile(`{tpath}/{path}`, str)
	end,
	delfile = function(path: string): ()
		delfile(`{tpath}/{path}`)
	end,
	isfile = function(path: string): boolean
		return isfile(`{tpath}/{path}`)
	end,
	getcustomasset = getcustomasset and function(path: string): string
		return getcustomasset(`{tpath}/{path}`)
	end,
}

makefolder(tpath)
addon.makefolder("cache")

Module = {}
Module.LoadCustomAsset = function(url: string, name: string?): string?
	if addon.getcustomasset then
		local fileName = `cache/{name}` or `cache/TMP_{tick()}`
		local success, result = pcall(addon.getcustomasset, fileName)
		result = success and result
		if result then
			return result
		elseif url:lower():sub(1, 4) == 'http' then
			addon.writefile(fileName, game:HttpGet(url))
			result = addon.getcustomasset(fileName)
			if not name then
				addon.delfile(fileName)
			end
			return result
		elseif addon.isfile(url) then
			return addon.getcustomasset(url)
		end
	else
		warn("Executor doesn't support 'getcustomasset', rbxassetid only.")
	end
	if url:find('rbxassetid') or tonumber(url) then
		return 'rbxassetid://'..url:match('%d+')
	end
	error(debug.traceback('Failed to load custom asset for:\n'..url))
end

Module.LoadCustomInstance = function(url: string, name: string?): Instance?
	local s, r = pcall(function()
		return game:GetObjects(Module.LoadCustomAsset(url, name))[1]
	end)
	return s and r or nil
end

local normal = "crown"

local Groupbox, Groupbox2 = mspaint.Groupbox, mspaint.Groupbox
local Window = Groupbox.Tab.Window
if ADDON_CONFIG.SeparateTabForAddon then
	if game.GameId == 2440500124 then
		local tabName = game.PlaceId == 6516141723 and "Practice" or "Other"
		if Groupbox.Visible then
			Groupbox:Hide()
		end
		local ReloadFunc = Groupbox.Elements[1].Func
		local Tab = Library.Tabs[Info.AddonTitle]
		local Groupboxes = Tab and Tab.Groupboxes
		local Addon = Groupboxes and Groupboxes.Addon
		Groupbox = Groupboxes and Groupboxes.Main
		Groupbox2 = Groupboxes and Groupboxes[tabName]
		if Addon then
			Addon:Destroy()
		end
		if Groupbox then
			Groupbox:Destroy()
		end
		if Groupbox2 then
			Groupbox2:Destroy()
		end
		local tab = Tab or Window:AddTab(Info.AddonTitle, normal)
		Addon = tab:AddRightGroupbox("Addon")
		Groupbox = tab:AddLeftGroupbox("Main")
		Groupbox2 = tab:AddRightGroupbox(tabName)
		Addon:AddLabel(Info.AddonFullTitle)
        Addon:AddLabel('<font color="#FFD700">Mr H - Owner</font>')
        Addon:AddLabel('<font color="#90EE90">Tplay-Created some features</font>')
		local button = Addon:AddButton(prefix.."CustomReloadLol", {
			Text = "Reload Addon",
			Tooltip = not debug.setinfo and "Addon might be broken after reloading it on your executor",
			Func = ReloadFunc,
			Risky = not debug.setinfo,
			Disabled = true
		})
		task.delay(3, button.SetDisabled, button, false)
	else
		Groupbox2 = nil
		if Groupbox.Visible then
			Groupbox:Hide()
		end
		local ReloadFunc = Groupbox.Elements[1].Func
		local Tab = Library.Tabs[Info.AddonTitle]
		local Groupboxes = Tab and Tab.Groupboxes
		local Addon = Groupboxes and Groupboxes.Addon
		Groupbox = Groupboxes and Groupboxes.Main
		if Addon then
			Addon:Destroy()
		end
		if Groupbox then
			Groupbox:Destroy()
		end
		local tab = Tab or Window:AddTab(Info.AddonTitle, normal)
		Addon = tab:AddRightGroupbox("Addon")
		Groupbox = tab:AddLeftGroupbox("Main")
		Addon:AddLabel(Info.AddonFullTitle)
        Addon:AddLabel('<font color="#FFD700">Mr H - Owner</font>')
        Addon:AddLabel('<font color="#90EE90">Tplay-Created some features</font>')
		Addon:AddButton(prefix.."CustomReloadLol", {
			Text = "Reload Addon",
			Tooltip = not debug.setinfo and "Addon might be broken after reloading it on your executor",
			Func = ReloadFunc,
			Risky = not debug.setinfo
		})
	end
end

if game.GameId == 2440500124 then
	local Camera = workspace.CurrentCamera
	local RemotesFolder = Services.ReplicatedStorage:WaitForChild("RemotesFolder", 999)
	local GameData = Services.ReplicatedStorage:WaitForChild("GameData", 999)
	local Projectiles = Services.ReplicatedStorage:WaitForChild("Projectiles", 999)
	local ReplicaDataModule = require(Services.ReplicatedStorage:WaitForChild("ReplicaDataModule", 999))
	local Floor = GameData:WaitForChild("FloorDestination", 999).Value
	local FloorSpecific = GameData:WaitForChild("FloorDestinationSpecific", 999).Value
	local LatestRoom = GameData:WaitForChild("LatestRoom", 999)
	local OpenedFirstDoor = GameData:WaitForChild("OpenedFirstDoor", 999)
	local PlayerRigs = Services.ReplicatedStorage:WaitForChild("PlayerRigs", 999)

	local TPPath = Services.PathfindingService:CreatePath({
		AgentRadius = 1,
		AgentHeight = 1,
		AgentCanJump = true,
		AgentCanClimb = true,
		WaypointSpacing = 3
	})

	local Crouch = RemotesFolder.Crouch
	local FireToolProjectile = RemotesFolder.FireToolProjectile
	local DropItem = RemotesFolder.DropItem
	local Revive = RemotesFolder.Revive
	local RequestLocalAsset = RemotesFolder.RequestLocalAsset
	local ObtainGiftedRevive = RemotesFolder.ObtainGiftedRevive
	local Footstep = RemotesFolder.FootstepRemoteThatWeNeed
	local DeathHint = RemotesFolder.DeathHint
	local Statistics = RemotesFolder.Statistics
	local RippleStatistics = RemotesFolder.RippleStatistics
	local MotorReplication = RemotesFolder.MotorReplication
	local ServerTeleported = RemotesFolder.ServerTeleported
	local UpdateMinecartNodes = RemotesFolder.UpdateMinecartNodes
	local MinecartPos = RemotesFolder.MinecartPos
	local MinecartResult = RemotesFolder.MinecartResult
	local ReplicateAnimation = RemotesFolder.ReplicateAnimation
	local TargetCameraDirection = RemotesFolder.TargetCameraDirection
	local Cutscene = RemotesFolder.Cutscene
	local ContinueOrSave = RemotesFolder.ContinueOrSave
	local PlayAgain = RemotesFolder.PlayAgain
	local SurgeRemote = RemotesFolder.SurgeRemote
	local CartControl = RemotesFolder.CartControl

	local LocalPlayer = Services.Players.LocalPlayer
	local PlayerGui = LocalPlayer.PlayerGui
	local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

	local CurrentRooms = workspace:WaitForChild('CurrentRooms', 999)
	local LiveEntities = workspace:WaitForChild('LiveEntities', 999)
	local Drops = workspace:WaitForChild('Drops', 999)
	local Misc = workspace:WaitForChild('Misc', 999)
	
	local teleportdata = Services.TeleportService:GetLocalPlayerTeleportData()
	
	local main_game = PlayerGui:WaitForChild("MainUI", 999):WaitForChild("Initiator", 999):WaitForChild("Main_Game", 999)
	local required_main_game = require(main_game)

	local Connections = {}
	local ItemsFromAddon = {}
	local StuffToRemoveLater = {}

    -- Observable movement samples, not the NPC's private AI waypoints.
    do
        local enabled, folder, heartbeat = false, nil, nil
        local tracked = {}
        local names = {RushMoving=true, AmbushMoving=true, BackdoorRush=true,
            A60=true, A120=true, FigureRig=true, FigureRagdoll=true,
            GrumbleRig=true, Grumble=true, SeekMoving=true, SeekRig=true}
        local function clearTrack(model)
            local track = tracked[model]
            if track then track.folder:Destroy() tracked[model] = nil end
        end
        local function stop()
            enabled = false
            if heartbeat then heartbeat:Disconnect() heartbeat=nil end
            if folder then folder:Destroy() folder=nil end
            tracked = {}
        end
        local function consider(model, live)
            if not model:IsA("Model") or tracked[model] then return end
            if not names[model.Name] and not (live and model:FindFirstChildOfClass("Humanoid")) then return end
            if Services.Players:GetPlayerFromCharacter(model) then return end
            local count=0
            for _ in pairs(tracked) do count=count+1 end
            if count>=16 then return end
            local container=Instance.new("Folder")
            container.Name=model.Name.."Trail"
            container.Parent=folder
            tracked[model]={folder=container, nodes={}}
        end
        local function scan()
            for _, object in ipairs(workspace:GetChildren()) do consider(object,false) end
            for _, object in ipairs(LiveEntities:GetDescendants()) do consider(object,true) end
            for _, object in ipairs(CurrentRooms:GetDescendants()) do
                if names[object.Name] then consider(object,false) end
            end
        end
        local function sample(model,track)
            local part=model.PrimaryPart or model:FindFirstChild("HumanoidRootPart",true)
                or model:FindFirstChildWhichIsA("BasePart",true)
            if not part then return end
            local position=part.Position
            local previous=track.nodes[#track.nodes]
            local distance=previous and (position-previous.Position).Magnitude or 0
            if previous and distance<2 then return end
            if previous and distance>200 then
                -- Avoid drawing a line across respawns or scripted teleports.
                for _, node in ipairs(track.nodes) do node:Destroy() end
                track.nodes={} previous=nil
            end
            local color=model.Name=="AmbushMoving" and Color3.fromRGB(100,255,140)
                or model.Name=="RushMoving" and Color3.fromRGB(255,100,100)
                or Color3.fromRGB(255,215,0)
            local node=Instance.new("Part")
            node.Name="ObservedNode"
            node.Shape=Enum.PartType.Ball
            node.Size=Vector3.new(0.45,0.45,0.45)
            node.Anchored=true node.CanCollide=false node.CanTouch=false node.CanQuery=false
            node.Material=Enum.Material.Neon node.Color=color
            node.Position=position
            local attachment=Instance.new("Attachment") attachment.Parent=node
            if previous then
                local beam=Instance.new("Beam")
                beam.Attachment0=previous:FindFirstChildOfClass("Attachment")
                beam.Attachment1=attachment
                beam.Width0=0.15 beam.Width1=0.15 beam.FaceCamera=true
                beam.Color=ColorSequence.new(color)
                beam.Transparency=NumberSequence.new(0)
                beam.Parent=node
            end
            node.Parent=track.folder
            table.insert(track.nodes,node)
            if #track.nodes>80 then
                table.remove(track.nodes,1):Destroy()
                local beam=track.nodes[1]:FindFirstChildOfClass("Beam")
                if beam then beam:Destroy() end
            end
        end
        Groupbox2:AddDivider({Text="ENTITY PATH"})
        Toggles.MrHEntityPathNodes=Groupbox2:AddToggle(prefix.."EntityPathNodes", {
            Text="Entity Path Nodes", Default=false,
            Tooltip="3D movement trails for loaded Rush, Ambush, A60/A120, Figure, Grumble, Seek and humanoid NPCs in LiveEntities. Shows observed movement, not future AI routes.",
            Callback=function(value)
                stop()
                if not value then return end
                enabled=true
                folder=Instance.new("Folder") folder.Name="MrHEntityPathNodes" folder.Parent=workspace
                scan()
                local elapsed,scanElapsed=0,0
                heartbeat=Services.RunService.Heartbeat:Connect(function(dt)
                    if not enabled then return end
                    elapsed=elapsed+dt scanElapsed=scanElapsed+dt
                    if scanElapsed>=1 then scanElapsed=0 scan() end
                    if elapsed<0.1 then return end
                    elapsed=0
                    for model,track in pairs(tracked) do
                        if not model:IsDescendantOf(workspace) then clearTrack(model)
                        else sample(model,track) end
                    end
                end)
            end,
        })
        OnUnload(stop)
    end


    -- Uses the shared MSESP library; cleanup only touches this addon's objects.
    do
        local esp,loading,closed=nil,false,false
        local groups={
            Drawer={enabled=false,color=Color3.fromRGB(255,215,0),objects={}},
            Stairwell={enabled=false,color=Color3.fromRGB(120,210,255),objects={}},
        }
        local function clear(group)
            for model,obj in pairs(group.objects) do
                if not obj.Deleted then obj:Destroy() end
                group.objects[model]=nil
            end
        end
        local function stairwellTarget(object)
            if not object:IsA("Model") and not object:IsA("BasePart") then return false end
            local name=object.Name:lower():gsub("[^%w]","")
            if name:find("exit",1,true) then return false end
            if name=="stairwellentrance" or name=="stairwellentrancedoor"
                or name=="stairwellentry" or name=="stairwellentrydoor" then return true end
            -- Also recognize a doorway explicitly marked with its destination.
            if name:find("door",1,true) or name:find("entrance",1,true) then
                for _,attribute in ipairs({"FloorDestination","Destination","DestinationFloor"}) do
                    if object:GetAttribute(attribute)=="Stairwell" then return true end
                end
            end
            return false
        end
        local function refresh()
            if closed or not esp then return end
            local wanted={Drawer={},Stairwell={}}
            local drawers={}
            local root=Character and Character:FindFirstChild("HumanoidRootPart")
            for _,object in ipairs(CurrentRooms:GetDescendants()) do
                if groups.Drawer.enabled and object:IsA("Model") and object.Name=="DrawerContainer" then
                    local part=object:FindFirstChild("Main") or object.PrimaryPart
                    if part and part:IsA("BasePart") then
                        drawers[#drawers+1]={model=object,distance=root and (part.Position-root.Position).Magnitude or 0}
                    end
                end
                if groups.Stairwell.enabled and stairwellTarget(object) then
                    local parent=object.Parent
                    if not (parent and stairwellTarget(parent)) then wanted.Stairwell[object]=true end
                end
            end
            table.sort(drawers,function(a,b) return a.distance<b.distance end)
            for i=1,math.min(24,#drawers) do wanted.Drawer[drawers[i].model]=true end
            for kind,group in pairs(groups) do
                for model,obj in pairs(group.objects) do
                    if not wanted[kind][model] or obj.Deleted then
                        if not obj.Deleted then obj:Destroy() end
                        group.objects[model]=nil
                    end
                end
                for model in pairs(wanted[kind]) do
                    if not group.objects[model] then
                        group.objects[model]=esp:Add({
                            Name=kind=="Drawer" and "Drawer" or "Stairwell Entrance",
                            Model=model, ESPType="Highlight", Visible=true,
                            Color=group.color,FillColor=group.color,OutlineColor=group.color,
                            FillTransparency=0.7,OutlineTransparency=0,MaxDistance=5000,
                        })
                    end
                end
            end
        end
        local function ensureLibrary()
            if closed or loading then return end
            if esp then refresh() return end
            loading=true
            task.spawn(function()
                local ok,result=pcall(function()
                    local shared=getgenv().mstudio45_ESP
                    if shared and type(shared.Add)=="function" then return shared end
                    return loadstring(game:HttpGet("https://raw.githubusercontent.com/mstudio45/MSESP/refs/heads/main/source.luau"))()
                end)
                loading=false
                if closed then return end
                if ok and result and type(result.Add)=="function" then esp=result refresh()
                else
                    Library:Notify({Title="Mr H ESP",Description="ESP library failed to load. Toggle ESP off and on to retry. "..tostring(result),Time=8})
                end
            end)
        end
        Groupbox:AddDivider({Text="ESP"})
        for _,kind in ipairs({"Drawer","Stairwell"}) do
            local key=kind
            local group=groups[key]
            local label=key=="Drawer" and "Drawer ESP" or "Stairwell Entrance ESP"
            local toggle=Groupbox:AddToggle(prefix..(key=="Drawer" and "DrawerESP" or "StairwellEntranceESP"),{
                Text=label,Default=false,
                Tooltip=key=="Drawer" and "Nearest 24 loaded drawers, rendered with MSESP." or "Loaded entrance models or doorways marked with Stairwell as their destination.",
                Callback=function(value)
                    group.enabled=value
                    if value then ensureLibrary() else clear(group) end
                end,
            })
            Toggles[key=="Drawer" and "MrHDrawerESP" or "MrHStairwellESP"]=toggle
            toggle:AddColorPicker(prefix..key.."ESPColor",{
                Default=group.color,Title=label.." Color",
                Callback=function(color)
                    group.color=color
                    for _,obj in pairs(group.objects) do
                        if not obj.Deleted then obj:SetEveryColor(color,true) end
                    end
                end,
            })
        end
        local elapsed=0
        local connection=Services.RunService.Heartbeat:Connect(function(dt)
            if closed or not esp or not (groups.Drawer.enabled or groups.Stairwell.enabled) then return end
            elapsed=elapsed+dt
            if elapsed>=0.5 then elapsed=0 refresh() end
        end)
        OnUnload(function()
            closed=true connection:Disconnect()
            for _,group in pairs(groups) do clear(group) end
        end)
    end


	local thinkanims = {'18885101321', '18885098453', '18885095182'}

	type Weld = {
		Destroy: (self: Weld) -> ()
	}

	function WeldTo(TargetPart: BasePart, Offset: CFrame): Weld
		local Root = Character and Character:WaitForChild("HumanoidRootPart", 10)
		if not Root then return end
		if not TargetPart then return end

		local Weld = {}
		local Connection = nil
		local OldAllowSleep = settings().Physics.AllowSleep

		settings().Physics.AllowSleep = false
		Connection = Services.RunService.Heartbeat:Connect(function()
			if not Character.Parent or not TargetPart.Parent then
				if Weld and Weld.Destroy then Weld:Destroy() end
				return
			end
			local clamp = Vector3.new(math.clamp(TargetPart.AssemblyLinearVelocity.X,-10,10),0,math.clamp(TargetPart.AssemblyLinearVelocity.Z,-10,10))
			Character:PivotTo(TargetPart.CFrame * Offset + clamp / 10)
			Root.AssemblyLinearVelocity = Vector3.zero
			Root.AssemblyAngularVelocity = Vector3.zero
			if sethiddenproperty then
				pcall(sethiddenproperty, Root, "PhysicsRepRootPart", TargetPart)
			end
		end)

		Weld.OldAllowSleep = OldAllowSleep

		function Weld:Destroy()
			if Connection then Connection:Disconnect() end
			if Root then
				Root.AssemblyLinearVelocity = Vector3.zero
				Root.AssemblyAngularVelocity = Vector3.zero
			end
			if sethiddenproperty then
				pcall(sethiddenproperty, Root, "PhysicsRepRootPart", nil)
			end
			self.Destroy = nil
		end

		return Weld
	end

	function inWhatRoom(object: Object): number?
		local parent = object.Parent
		while not parent or parent.Name:match("%d+") ~= parent.Name do
			parent = parent.Parent
		end
		return parent and parent.Parent == CurrentRooms and tonumber(parent.Name)
	end

	function decodeBase64(str: string)
		return buffer.tostring(Services.EncodingService:Base64Decode(buffer.fromstring(str)))
	end

	StuffToRemoveLater.ObtainedRevive = PlayerGui:WaitForChild("MainUI", 99):WaitForChild("ObtainedRevive", 99):Clone()
	StuffToRemoveLater.ObtainedRevive.Confirm.Size = UDim2.fromScale(.3,.2)
	StuffToRemoveLater.ObtainedRevive.Close.Size = UDim2.fromScale(.3,.2)
	StuffToRemoveLater.ObtainedRevive.Confirm.Position = UDim2.fromScale(.3,1)
	StuffToRemoveLater.ObtainedRevive.Close.Position = UDim2.fromScale(.7,1)
	StuffToRemoveLater.ObtainedRevive.Confirm.Text = "KEEP"

	Variables.Keep = StuffToRemoveLater.ObtainedRevive.Confirm:Clone()
	Variables.Keep.Parent = StuffToRemoveLater.ObtainedRevive
	Variables.Keep.AnchorPoint = Vector2.new(.5,1)
	Variables.Keep.Position = UDim2.fromScale(.5,1)
	Variables.Keep.Size = UDim2.fromScale(1/3,.2)
	Variables.Keep.BackgroundColor3 = Color3.fromRGB(165, 168, 207)
	Variables.Keep.Name = "Keep"
	Variables.Keep.Text = "KEEP 1X"
	Variables.Keep = nil

	Variables.pendingGiftedRevives = {}
	Variables.pendingGiftedRevivesALL = {}
	Variables.blacklisted = {}
	Variables.infYield = Instance.new("BindableFunction")

	Variables.disableGifting = false
	function OnReviveObtain(name)
		if Variables.disableGifting or Variables.blacklisted[name] then
			Variables.infYield:Invoke()
			return false
		elseif not (main_game and require(main_game).dead) then
			return false
		end

		local guid = Services.HttpService:GenerateGUID(false)
		local player = Services.Players:FindFirstChild(name)
		Variables.pendingGiftedRevives[name] = Variables.pendingGiftedRevives[name] or {}
		table.insert(Variables.pendingGiftedRevives[name], guid)

		local LiveRevive = PlayerGui.MainUI:FindFirstChild("FriendReviveLive")
		if LiveRevive and LiveRevive:GetAttribute("name") == name then
			LiveRevive.Keep.Text = `KEEP {#Variables.pendingGiftedRevives[name]}X`
		end

		table.insert(Variables.pendingGiftedRevivesALL, `{name}-[{guid}]`)
		local index = table.find(Variables.pendingGiftedRevivesALL, `{name}-[{guid}]`)
		while index and index > 1 do
			index = table.find(Variables.pendingGiftedRevivesALL, `{name}-[{guid}]`)
			task.wait()
		end

		local FriendRevive = ObtainedRevive:Clone()
		FriendRevive:SetAttribute("name", name)
		FriendRevive.Name = "FriendReviveLive"
		FriendRevive.Parent = PlayerGui.MainUI
		FriendRevive.Player.Username.Text = name
		FriendRevive.Keep.Text = `KEEP {#pendingGiftedRevives[name]}X`

		task.spawn(function()
			local success, userId = pcall(function()
				return player and player.UserId or Services.Players:GetUserIdFromNameAsync(name)
			end)
			userId = success and userId
			FriendRevive.Player.PlayerIcon.Image = `rbxthumb://type=AvatarHeadShot&id={userId or 1}&w=150&h=150`
		end)

		FriendRevive.Timer.Text = "inf"
		FriendRevive.Visible = true

		local accepted = nil
		FriendRevive.Confirm.MouseButton1Down:Once(function()
			accepted = 1
			FriendRevive.Visible = false
		end)
		FriendRevive.Keep.MouseButton1Down:Once(function()
			accepted = 2
			FriendRevive.Visible = false
		end)
		FriendRevive.Close.MouseButton1Down:Once(function()
			accepted = false
			FriendRevive.Visible = false
		end)
		index = table.find(Variables.pendingGiftedRevives[name], guid)
		while Variables.pendingGiftedRevives[name] and Variables.pendingGiftedRevives[name][index] == guid and accepted == nil do
			task.wait()
		end
		if not (Variables.pendingGiftedRevives[name] and Variables.pendingGiftedRevives[name][index]) then
			return not (Variables.blacklisted[name] or LocalPlayer:GetAttribute("Alive"))
		end
		if accepted ~= 2 then
			pcall(table.remove, Variables.pendingGiftedRevives[name], index)
			index = table.find(Variables.pendingGiftedRevivesALL, `{name}-[{guid}]`)
			pcall(table.remove, Variables.pendingGiftedRevivesALL, index)
		elseif accepted == false then
			Variables.blacklisted[name] = true
			for _, guid in Variables.pendingGiftedRevives[name] do
				local oIndex = table.find(Variables.pendingGiftedRevivesALL, `{name}-[{guid}]`)
				pcall(table.remove, Variables.pendingGiftedRevives[name], index)
				pcall(table.remove, Variables.pendingGiftedRevivesALL, oIndex)
			end
			Variables.pendingGiftedRevives[name] = {}
		else
			for _, guid in Variables.pendingGiftedRevives[name] do
				local oIndex = table.find(Variables.pendingGiftedRevivesALL, `{name}-[{guid}]`)
				pcall(table.remove, Variables.pendingGiftedRevives[name], index)
				pcall(table.remove, Variables.pendingGiftedRevivesALL, oIndex)
			end
			Variables.pendingGiftedRevives[name] = {}
		end
		return not not accepted
	end

	Connections.CameraChanged = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		Camera = workspace.CurrentCamera
	end)

	function isModifierEnabled(modifier)
		return not not(teleportdata and teleportdata.Modifiers and table.find(teleportdata.Modifiers, modifier))
	end

	local ScreenGui, delulucaption, spawncaption, script1
	task.spawn(function()
		ScreenGui = Instance.new('ScreenGui', PlayerGui)
		ScreenGui.Name = 'DeluluCaption'
		ScreenGui.DisplayOrder = PlayerGui.MainUI.DisplayOrder
		ScreenGui.ResetOnSpawn = false
		ScreenGui.IgnoreGuiInset = true
		delulucaption = Module.LoadCustomInstance('https://github.com/tplaygd/Tplays-Addon-Stuff/raw/main/caption.rbxm', "caption.rbxm")

		if delulucaption then
			delulucaption.Parent = ScreenGui
			script1 = Instance.new('LocalScript', delulucaption)
			local v_u_1 = Services.TweenService
			local v_u_2 = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			local tbas = Instance.new('Sound')
			tbas.SoundId = 'rbxassetid://6895079853'

			spawncaption = function(p3, p4, p5, p6, p7)
				local v8 = p3:Clone()
				v8.Parent = p4
				v8:WaitForChild('MainText').Text = ''
				local v9 = v8.Size
				v8.Size = UDim2.new(0, 0, 1, 0)
				v8.Visible = true
				Services.SoundService:PlayLocalSound(tbas)
				v_u_1:Create(v8, v_u_2, {
					['Size'] = v9
				}):Play()
				local v10 = Instance.new('Sound')
				v10.Parent = script1
				if p6 ~= nil and p6 ~= 'none' then
					v10.SoundId = p6
				else
					v10.SoundId = 'rbxassetid://7107161936'
				end
				if p7 ~= nil and p7 ~= 'none' then
					v8:WaitForChild('MainText').TextColor3 = p7
				end
				Services.Debris:AddItem(v8, 3.1+1+(0.0175*#p5))
				task.wait(0.4)
				v8:WaitForChild('MainText').Visible = true
				for v11 = 1, #p5 do
					v8:WaitForChild('MainText').Text = p5:sub(1, v11)
					Services.SoundService:PlayLocalSound(v10)
					task.wait(0.0175)
				end
				task.wait(2.5)
				Services.TweenService:Create(v8:WaitForChild('MainText'), TweenInfo.new(0.2), {
					['TextTransparency'] = 1
				}):Play()
				Services.TweenService:Create(v8:WaitForChild('MainText'):WaitForChild('UIStroke'), TweenInfo.new(0.2), {
					['Transparency'] = 1
				}):Play()
				task.wait(0.2)
				v_u_1:Create(v8, v_u_2, {
					['Size'] = UDim2.new(0, 0, 1, 0)
				}):Play()
			end
		end
	end)

	Variables.doorReach = false
	Variables.oldUpValues = {}
	Connections.coolconn = LocalPlayer.CharacterAdded:Connect(function(character)
		main_game = PlayerGui:WaitForChild("MainUI", 999):WaitForChild("Initiator", 999):WaitForChild("Main_Game", 999)
		if Toggles.Freecam.Value then
			Toggles.Freecam:SetValue(false)
		end
		required_main_game = require(main_game)
		if Toggles.Stun.Value then
			Toggles.Stun.Callback(false, true)
		end
		if Toggles.SlideSpeedHack.Value then
			Crouch:FireServer(Character:GetAttribute("Crouching"), true)
		end
		if Toggles.UpsideDown.Value then
			pcall(Toggles.UpsideDown.Callback, false, true)
			task.spawn(function()
				Character:WaitForChild("CollisionPart", 1/0)
				task.delay(.1, Toggles.UpsideDown.Callback, true)
			end)
		end
		Character = character
		if Connections.OnCharacterStun then
			Connections.OnCharacterStun:Disconnect()
		end
		Connections.OnCharacterStun = Character:GetAttributeChangedSignal('Stunned'):Connect(function()
			Toggles.Stun.Callback(Character:GetAttribute('Stunned'), true)
		end)
		Variables.blacklisted = {}
		Variables.pendingGiftedRevives = {}
		Variables.pendingGiftedRevivesALL = {}
	end)

	Connections.OnCharacterStun = Character:GetAttributeChangedSignal('Stunned'):Connect(function()
		Toggles.Stun.Callback(Character:GetAttribute('Stunned'), true)
	end)

	local success, username = pcall(function()
		return Services.Players:GetNameFromUserIdAsync(teleportdata.Host)
	end)

	Groupbox:AddDivider({
		Text = "GAME INFO",
		MarginTop = 2,
		MarginBottom = -2
	})
	if teleportdata.Host and success and username then
		local player = Services.Players:GetPlayerByUserId(teleportdata.Host)
		Groupbox:AddLabel('Host UserId: '..teleportdata.Host or "???")
		Groupbox:AddLabel('Host Username: '..Services.Players:GetNameFromUserIdAsync(teleportdata.Host) or "???")
		local status = Groupbox:AddLabel('Status: '..(player and 'In-game' or 'Left'))
		if player then
			Connections.OnHostLeft = Services.Players.ChildRemoved:Connect(function(leftPlayer)
				if leftPlayer == player then
					Connections.OnHostLeft:Disconnect()
					Connections.OnHostLeft = nil
					status:SetText('Status: Left')
				end
			end)
		end
	else
		Groupbox:AddLabel('HOST NOT FOUND')
	end

	Groupbox:AddDivider({
		Margin = -6
	})

	Variables.playersInGame = Groupbox:AddLabel(`Players: {#Services.Players:GetPlayers()}/{#PlayerRigs:GetChildren()}`)
	Connections.OnPlayerLeft = Services.Players.ChildRemoved:Connect(function()
		Variables.playersInGame:SetText(`Players: {#Services.Players:GetPlayers()}/{#PlayerRigs:GetChildren()}`)
	end)

	Groupbox:AddDivider({
		Text = "MAIN",
		MarginTop = 2,
		MarginBottom = -2
	})

	Variables.motorReplicaAbuse = {
		methods = {
			HandsUp = {
				number = 72000,
				static = false,
				methodType = "Number"
			},
			Zombie = {
				number = -36000,
				static = false,
				methodType = "Number"
			},
			BodyInLegs = {
				number = 3600,
				static = false,
				methodType = "Number"
			},
			BrokenSpine = {
				number = 1800,
				static = true,
				methodType = "Number"
			},
			Spin = function()
				local currentLVY = 0
				local v1 = os.clock()+1/30
				local v2 = 0
				return Services.RunService.RenderStepped:Connect(function(dt)
					if os.clock() < v1 then v2 += dt return end
					currentLVY = currentLVY+v2*7200*Variables.MotorSpeed.Value
					MotorReplication:FireServer(-currentLVY)
					v1 = os.clock()+1/30
					v2 = 0
				end)
			end,
			CrazySpin = function()
				local currentLVY = 0
				local mode = 1
				local v1 = os.clock()+1/30
				local v2 = 0
				local v3 = -1
				return Services.RunService.RenderStepped:Connect(function(dt)
					if os.clock() < v1 then v2 += dt return end
					currentLVY = currentLVY+v2*7200*Variables.MotorSpeed.Value
					if mode == 1 and currentLVY >= 7200 then
						mode = -1
						currentLVY *= -1
					elseif mode == -1 and currentLVY >= 0 then
						mode = 1
					end
					MotorReplication:FireServer(currentLVY*v3)
					v3 *= -1
					v1 = os.clock()+1/30
					v2 = 0
				end)
			end
		},
		method = "BrokenSpine",
		enabled = false
	}
	Variables.showPathfind = false
	Variables.cogAlt = false
	Variables.slideSH = false
	Variables.noReviveCutscene = false
	Variables.noSpread = false
	Variables.fastThrow = false
	Variables.minecartTp = false
	Variables.propsFastSpeed = {
		Bomb = 300,
		BigBomb = 300,
		Knockbomb = 250,
		GoldBullet = 10000,
		Bullet = 10000,
		PaperPlane = 150
	}
	Variables.hook = hookmetamethod and hookmetamethod(game, "__namecall", function(self, ...)
		local args, method = {...}, getnamecallmethod()
		if self == Crouch and method == "FireServer" then
			if Variables.cogAlt then
				args[1] = true
			end
			if Variables.slideSH then
				args[2] = true
			end
		end
		--[[if not checkcaller() and self == Footstep and method == "FireServer" and antiFigure then
			return
		end]]
		local name = ...
		if not checkcaller() and method == "WaitForChild" then
			if (name == "PathfindNodes" and Variables.showPathfind) or (name == "ReviveCutscene" and Variables.noReviveCutscene) then
				return
			end
		end
		if not checkcaller() and self == MinecartPos and getnamecallmethod() == "FireServer" and Variables.minecartTp then
			local cframe = ...
			local latestroom = LatestRoom.Value
			if latestroom < 50 then
				local room = workspace.CurrentRooms:FindFirstChild(latestroom)
				local door = room and room:FindFirstChild("Door")
				if door then
					cframe = door:GetPivot()
					workspace.CurrentCamera.MinecartRig:PivotTo(cframe)
					door.ClientOpen:FireServer()
				end
			else
				task.delay(.5, function()
					MinecartResult:FireServer("Derail", "NestCutscene")
				end)
			end
			return Variables.hook(self, cframe)
		end
		if Variables.motorReplicaAbuse.enabled and self == MotorReplication and method == "FireServer" then
			local value = Variables.motorReplicaAbuse.methods[Variables.motorReplicaAbuse.method]
			if typeof(value) == "table" and value.methodType == "Number" then
				args[1] = value.number+(not value.static and args[1] or 0)
			elseif not checkcaller() then
				return
			end
		end
		if self == FireToolProjectile and method == "Fire" then
			--args[1] = args[1] == "GoldBullet" and "Bullet" or args[1]
			args[3] = Variables.noSpread and Camera.CFrame.Position or args[3]
			args[4] = Variables.noSpread and Camera.CFrame.LookVector or args[4]
			args[5] = Variables.fastThrow and (Variables.propsFastSpeed[args[1]] or 500) or args[5]
		end
		return Variables.hook(self, unpack(args))
	end)

	Variables.AllPathfindNodes = {}
	CurrentRooms.ChildAdded:Connect(function(room)
		local PathfindNodes = Variables.showPathfind and room:WaitForChild("PathfindNodes", 1)
		if PathfindNodes then
			table.insert(Variables.AllPathfindNodes, PathfindNodes)
			for _, node in PathfindNodes:GetChildren() do
				node.Transparency = .5
			end
		end
	end)

	StuffToRemoveLater.body = Instance.new("BodyVelocity")
	StuffToRemoveLater.body.MaxForce = Vector3.new(1/0, 1/0, 1/0)

	function NoAltFeatures()
		if ADDON_CONFIG.AltFeatures then
			return nil
		else
			return {
				Value = false,
				Disabled = false,
				SetDisabled = function(self, value)
					self.Disabled = value
				end
			}
		end
	end

	function NoAlrAddedFeatures()
		if ADDON_CONFIG.IncludeAddedFeatures then
			return nil
		else
			return {
				Value = false,
				Disabled = false,
				SetDisabled = function(self, value)
					self.Disabled = value
				end
			}
		end
	end

	function FindChair(attachment)
		for _, base in Misc:QueryDescendants(`> #{Floor}OfficeChair > #Base`) do
			local align = base:FindFirstChild("CartAlignPosition")
			local collider = base.Parent:FindFirstChild("Collider")
			if collider and (align or isnetworkowner(collider)) then
				return base.Parent
			end
		end
		return nil
	end

	function FindAlingsForChairOrCart(attachment)
		for _, base in Misc:QueryDescendants(`> #{Floor}OfficeChair > #Base, > #ShoppingCart > #Base, > #TV_Stand > #Base`) do
			local alignPos = base:FindFirstChild("CartAlignPosition")
			local alignRot = base:FindFirstChild("CartAlignOrientation")
			if alignPos and alignRot then
				return alignPos, alignRot, base.Parent
			end
		end
		return nil, nil
	end

	Variables.ConnectingChair = false
	function ConnectChair(chair, promptBlock, restoring)
		if Variables.ConnectingChair then return end
		Variables.ConnectingChair = true
		if restoring then
			while (function()
				for _, descendant in Character:QueryDescendants("> #CollisionPart > #CartTargetAttachment") do
					if descendant:IsA("Attachment") then
						return false
					end
				end
				return true
			end)() do
				chair:PivotTo(Character:GetPivot()+Character:GetPivot().LookVector*5)
				fireproximityprompt(chair.Attachment.CartPrompt)
				task.wait()
			end
		end
		local collider = chair.Collider
		CartControl:FireServer()
		task.wait()
		local doo = true
		task.spawn(function()
			while doo do
				fireproximityprompt(collider.SeatPrompt)
				task.wait()
			end
		end)
		Character:GetAttributeChangedSignal("SeatedInSeat"):Wait()
		doo = false
		Character:SetAttribute("SeatedInSeat", false)
		task.wait()
		if Variables.ACBypassNotify then
			Variables.ACBypassNotify:Destroy()
			Variables.ACBypassNotify = nil
		end
		Library:Notify({
			Title = "Tplay's Addon",
			Description = "Anticheat was bypassed!",
			Time = 3
		})
		Variables.ConnectingChair = false
		local val = 0
		Connections.ChairConnection = Services.RunService.Heartbeat:Connect(function(dt)
			val = (val + dt * 3600) % 360
			collider.AssemblyLinearVelocity = Vector3.new(0,10000,0)
			chair:PivotTo(Character:GetPivot())
			Services.RunService.RenderStepped:Wait()
			chair:PivotTo(Character:GetPivot()-Vector3.new(0,-100,0))
		end)
		while Connections.ChairConnection and chair:IsDescendantOf(workspace) and isnetworkowner(promptBlock) and Character.Parent and Character:GetAttribute("SeatedInSeat") ~= nil do
			task.wait()
		end
		if Connections.ChairConnection and chair:IsDescendantOf(workspace) and isnetworkowner(promptBlock) and Character.Parent and Character:GetAttribute("DeathReason") ~= "Impact" then
			Character:SetAttribute("DeathReason", "_Impact")
			Variables.ACBypassNotify = Library:Notify({
				Title = "Tplay's Addon [Warning]",
				Description = "Anticheat bypass was broken, trying to restore it",
				Persist = true
			})
			log("WE CAN RESTORE!!!")
			ConnectChair(chair, promptBlock, true)
		else
			log(Connections.ChairConnection or "nil", chair:IsDescendantOf(workspace), isnetworkowner(promptBlock), Character.Parent or "nil")
			Variables.ACBypassNotify = Library:Notify({
				Title = "Tplay's Addon [Warning]",
				Description = "Anticheat bypass was broken, grab a chair again to restore it",
				Persist = true
			})
		end
		if Connections.ChairConnection then
			Connections.ChairConnection:Disconnect()
			Connections.ChairConnection = nil
		end
	end

	Toggles.AnticheatBypassAndFling = NoAlrAddedFeatures() or ((Floor ~= "Archives" and Floor ~= "Stairwell") and {Value = false}) or Groupbox:AddToggle(prefix..'AnticheatBypassAndFling', {
		Text = 'Anticheat Bypass',
		Tooltip = `Bypasses anticheat with {Floor} Chair`,
		Default = false,
			Callback = function(value, noNotify)
			if value then
				Variables.ACBypassNotify = Library:Notify({
					Title = "Tplay's Addon",
					Description = "Grab a chair to bypass anticheat",
					Persist = true
				})
				Connections.OnChairGrab = Character.DescendantAdded:Connect(function(descendant)
					if not Connections.ChairConnection and (not Toggles.FlingCreak.Value or Variables.ChairThatFlingsCreak) and descendant:IsA("Attachment") and descendant.Name == "CartTargetAttachment" and descendant.Parent.Name == "CollisionPart" then
						local chair = FindChair(descendant)
						local promptBlock = chair and chair:FindFirstChild("PromptBlocker")
						if promptBlock then
							ConnectChair(chair, promptBlock)
						end
					end
				end)
			else
				if Connections.OnChairGrab then
					Connections.OnChairGrab:Disconnect()
					Connections.OnChairGrab = nil
				end
				if Connections.ChairConnection then
					Connections.ChairConnection:Disconnect()
					Connections.ChairConnection = nil
				end
			end
		end
	})

	Connections.NotificationFix = Services.RunService.RenderStepped:Connect(function()
		if not Toggles.AnticheatBypassAndFling.Value and Variables.ACBypassNotify then
			Variables.ACBypassNotify:Destroy()
			Variables.ACBypassNotify = nil
		end
	end)

	Variables.noclipOn = false
	Variables.Noclip = Library.Toggles.Noclip
	Toggles.AnticheatManipulationAlt = NoAltFeatures() or Groupbox:AddToggle(prefix..'AnticheatManipulationAlt', {
		Text = 'Anticheat Manipulation Alt',
		Tooltip = "Alternative method of AC manipulation (from Abysall)",
		Default = false,

		Callback = function(value)
			if value then
				StuffToRemoveLater.body.Parent = Character.HumanoidRootPart
				Connections.ACMA = Services.RunService.RenderStepped:Connect(function()
					StuffToRemoveLater.body.Velocity = Camera.CFrame.LookVector * 2.25
				end)
				if Variables.Noclip.Value then
					Variables.noclipOn = true
				else
					pcall(Variables.Noclip.SetValue, Variables.Noclip, true)
				end
				pcall(Variables.Noclip.SetDisabled, Variables.Noclip, true)
			else
				StuffToRemoveLater.body.Parent = nil
				if Connections.ACMA then
					Connections.ACMA:Disconnect()
					Connections.ACMA = nil
				end
				pcall(Variables.Noclip.SetDisabled, Variables.Noclip, false)
				if not Variables.noclipOn then
					pcall(Variables.Noclip.SetValue, Variables.Noclip, false)
				end
				Variables.noclipOn = false
			end
		end
	})

	KeyPickers.AnticheatManipulationAltKey = Toggles.AnticheatManipulationAlt.Callback and Toggles.AnticheatManipulationAlt:AddKeyPicker(prefix.."AnticheatManipulationAltKey", {
		Text = "Anticheat Manipulation Alt",
		Default = "Y",
		Mode = Library.IsMobile and "Toggle" or "Hold",
		SyncToggleState = true
	})

	Variables.Groundskeepers = {}
	Variables.FigureRigs = {}

	Variables.stopTauntTimes = 0
	Variables.lastTaunt = -1/0

	function addGS(gs)
		if gs.Name == "Groundskeeper" and gs:WaitForChild("HumanoidRootPart", 1) then
			table.insert(Variables.Groundskeepers, gs)
			gs:WaitForChild("Head", 1/0).ChildAdded:Connect(function(child)
				if Toggles.GSNotifier.Value and child.Name:sub(1,7) == "gkgrunt" then
					lastTaunt = os.clock()
					Variables.stopTauntTimes += 1
					task.spawn(function()
						local staticTauntTimes = Variables.stopTauntTimes
						while staticTauntTimes == Variables.stopTauntTimes and lastTaunt < os.clock()-3 do
							task.wait()
						end
						if staticTauntTimes == Variables.stopTauntTimes then
							Variables.stopTauntTimes = 0
							if staticTauntTimes >= 3 then
								Library:Notify({
									Title = Info.AddonTitle.." [Groundskeeper]",
									Description = "Groundskeeper is not stuck anymore!",
									Time = 3
								})
							end
						end
					end)
					if Variables.stopTauntTimes == 3 then
						Library:Notify({
							Title = Info.AddonTitle.." [Groundskeeper]",
							Description = "Groundskeeper is stuck lol",
							Time = 3
						})
					end
				end
			end)
		end
	end

	local function addFR(fr)
		if fr.Name == "FigureRig" and fr:WaitForChild("Root", 1) then
			table.insert(Variables.FigureRigs, fr)
		end
	end

	for _, c in CurrentRooms:QueryDescendants("#Groundskeeper") do
		task.spawn(addGS, c)
	end
	for _, c in CurrentRooms:QueryDescendants("#FigureRig") do
		task.spawn(addFR, c)
	end
	CurrentRooms.DescendantAdded:Connect(addGS)
	CurrentRooms.DescendantAdded:Connect(addFR)
	CurrentRooms.DescendantRemoving:Connect(function(c)
		local foundGS = table.find(Variables.Groundskeepers, c)
		local foundFR = table.find(Variables.FigureRigs, c)
		if foundGS then
			table.remove(Variables.Groundskeepers, foundGS)
		end
		if foundFR then
			table.remove(Variables.FigureRigs, foundFR)
		end
	end)

	function ShouldSpoofGS(hrp)
		for _, gs in Variables.Groundskeepers do
			gs = gs:FindFirstChild("HumanoidRootPart")
			if gs and (gs.Position*Vector3.new(1,5,1)-hrp.Position*Vector3.new(1,5,1)).Magnitude < 90 then
				return true
			end
		end
		return false
	end

	function ShouldSpoofFR(hrp)
		for _, fr in Variables.FigureRigs do
			fr = fr:FindFirstChild("Root")
			if fr and (fr.Position*Vector3.new(1,0,1)-hrp.Position*Vector3.new(1,0,1)).Magnitude < 20 then
				return true
			end
		end
		return false
	end

	Groupbox:AddDivider({
		Margin = -6
	})

	Toggles.NoSpread = NoAlrAddedFeatures() or Groupbox:AddToggle(prefix..'NoSpread', {
		Text = 'No Spread',
		Tooltip = 'Accurate prop throw',
		DisabledTooltip = "Executor is not supported",
		Disabled = not Variables.hook,
		Default = false,

		Callback = function(value)
			Variables.accurateAim = value
		end
	})
		Toggles.FastThrow = NoAlrAddedFeatures() or Groupbox:AddToggle(prefix..'FastThrow', {
		Text = 'Fast Throw',
		Tooltip = 'Throws prop as fast as Gold Bullet',
		DisabledTooltip = "Executor is not supported",
		Disabled = not Variables.hook,
		Default = false,

		Callback = function(value)
			Variables.fastThrow = value
		end
	})

	Toggles.DeleteProps = Groupbox:AddToggle(prefix..'DeleteProps', {
		Text = 'Delete Props',
		Tooltip = 'Delete every prop you pickup (works only in Battle Mode)',

		Callback = function(value)
			if value then
				Connections.DeletePropsConnection = Character.ChildAdded:Connect(function(child)
					if child.Name == "BigPropTool" then
						child.Parent = LocalPlayer.Backpack
					end
				end)
			else
				if Connections.DeletePropsConnection then
					Connections.DeletePropsConnection:Disconnect()
					Connections.DeletePropsConnection = nil
				end
			end
		end
	})

	function GetEquippedTool(player: Player)
		return player and player.Character and player.Character:FindFirstChildOfClass("Tool")
	end

	Variables.reason = {
		Durability = "Gold Blaster should have Durability '1'",
		AlreadyBroken = "Gold Blaster is already broken"
	}

	KeyPickers.BreakToolKey = Groupbox:AddLabel('Use & Break Gold Blaster'):AddKeyPicker(prefix.."BreakToolKey", {
		Text = "Use & Break Gold Blaster",
		Default = "MB3",
		Mode = "Press",

		Callback = function()
			local tool = GetEquippedTool(LocalPlayer)
			if tool and tool.Name == "GoldGun" and not tool:GetAttribute("OnCooldown") and (tool:GetAttribute("Durability") and tool:GetAttribute("Durability") == 1) then
				GetFunction("FireTool", false, "Inventory")()
				task.wait(.2)
				DropItem:FireServer(tool)
			elseif tool and tool.Name == "GoldGun" then
				Library:Notify({
					Title = Info.AddonTitle.." [Error]",
					Description = Variables.reason[tool:GetAttribute("OnCooldown") and "AlreadyBroken" or "Durability"],
					Time = 3
				})
			else
				Library:Notify({
					Title = Info.AddonTitle.." [Error]",
					Description = "Wrong item",
					Time = 2
				})
			end
		end
	})

	Groupbox:AddDivider({
		Margin = -6
	})

	Toggles.ShowPathfind = Groupbox:AddToggle(prefix..'ShowPathfind', {
		Text = 'Show Pathfind Nodes',
		Tooltip = 'Show pathfind nodes that rush, ambush and etc. use to move',
		DisabledTooltip = 'Executor is not supported',
		Default = false,
		Disabled = not Variables.hook,

		Callback = function(value)
			Variables.showPathfind = value
			if not value then
				for _, PathfindNodes in Variables.AllPathfindNodes do
					PathfindNodes:Destroy()
				end
				Variables.AllPathfindNodes = {}
			end
		end
	})

	Variables.DoorReach = Library.Toggles.DoorReach
	Toggles.DoorReachAlt = NoAltFeatures() or Groupbox:AddToggle(prefix..'DoorReachAlt', {
		Text = 'Door Reach Alt',
		DisabledTooltip = 'Executor is not supported',
		Default = false,
		Disabled = not filtergc,

		Callback = function(value)
			Variables.doorReach = value
			main_game:WaitForChild("Updated", 9e9)
			if value then
				if Variables.DoorReach.Value then
					pcall(Variables.DoorReach.SetValue, Variables.DoorReach, false)
				end
				pcall(Variables.DoorReach.SetDisabled, Variables.DoorReach, true)
				local lastOpened = {Time = -1/0}
				while Variables.doorReach do
					local Root = Character and Character.PrimaryPart or Character:FindFirstChild("HumanoidRootPart")
					local Room = CurrentRooms:FindFirstChild(LatestRoom.Value)
					local Door = Room and Room:FindFirstChild("Door")
					local DoorPart = Door and Door.PrimaryPart
					if Root and DoorPart and not Door:FindFirstChild("Lock") then
						if (Root.Position-DoorPart.Position).Magnitude < 30 and (not lastOpened.Door == Door or lastOpened.Time < os.clock()-1/3) then
							lastOpened.Door = Door
							lastOpened.Time = os.clock()
							Door.ClientOpen:FireServer()
						end
					end
					Services.RunService.RenderStepped:Wait()
				end
			else
				pcall(Variables.DoorReach.SetDisabled, Variables.DoorReach, false)
			end
		end
	})

	Toggles.FastChairAndCart = Groupbox:AddToggle(prefix..'FastChairAndCart', {
		Text = 'Fast Chair & Cart',
		DisabledTooltip = 'Executor is not supported',
		Tooltip = `Similar to No Acceleration but for chairs and shopping carts`,
		Default = false,
		Disabled = not hookfunction,

		Callback = function(value, noNotify)
			if value then
				Connections.OnChairOrCartGrab = Character.DescendantAdded:Connect(function(descendant)
					if descendant:IsA("Attachment") and descendant.Name == "CartTargetAttachment" and descendant.Parent.Name == "CollisionPart" then
						local alignPos, alingRot, chair = FindAlingsForChairOrCart(descendant)
						if alignPos and alingRot and chair then
							alignPos:Destroy()
							alingRot:Destroy()
							while descendant.Parent do
								chair:PivotTo(Character:GetPivot() * CFrame.new(0,0,-3.75) - Vector3.new(0,1.3,0))
								chair.Base.AssemblyLinearVelocity = Character.PrimaryPart.AssemblyLinearVelocity
								chair.Base.AssemblyAngularVelocity = Character.PrimaryPart.AssemblyAngularVelocity
								Services.RunService.RenderStepped:Wait()
							end
						end
					end
				end)
			else
				if Connections.OnChairOrCartGrab then
					Connections.OnChairOrCartGrab:Disconnect()
					Connections.OnChairOrCartGrab = nil
				end
			end
		end
	})

	Groupbox:AddDivider({
		Margin = -6
	})

	StuffToRemoveLater.NilConstraint = Instance.new("PrismaticConstraint")
	function disconnectDrawer(drawer)
		(drawer:WaitForChild("Constraint", 1) or StuffToRemoveLater.NilConstraint).Enabled = true
		local drawer = Connections.DrawersConnections[drawer]
		for index, connection in drawer or {} do
			connection:Disconnect()
		end
		drawer = nil
	end

	function handleDrawer(drawer)
		local constraint, main
		if drawer:IsA("Model") and drawer.Name == "DrawerContainer" then
			main = drawer:WaitForChild("Main", 1)
			if not main then
				return
			end
			constraint = drawer:WaitForChild("Constraint", 1)
			if not constraint then
				return
			end
		else
			return
		end
		Connections.DrawersConnections = Connections.DrawersConnections or {}
		if Connections.DrawersConnections[drawer] then
			return
		end
		Connections.DrawersConnections[drawer] = {
			AncestryChanged1 = drawer.AncestryChanged:Connect(function()
				if not drawer.Parent then
					disconnectDrawer(drawer)
				end
			end),
			AncestryChanged2 = main.AncestryChanged:Connect(function()
				if not main.Parent then
					disconnectDrawer(drawer)
				end
			end),
			BringLoop = Services.RunService.RenderStepped:Connect(function()
				if isnetworkowner(main) and not main.Anchored then
					constraint.Enabled = false
					if Toggles.AutoFloor.Value then
						main.CFrame = Character:GetPivot()
					else
						main.CFrame = Character:GetPivot()*CFrame.Angles(0,math.rad(180),0)+Character:GetPivot().LookVector*3
					end
					main.AssemblyLinearVelocity = Vector3.zero
					main.AssemblyAngularVelocity = Vector3.zero
				else
					constraint.Enabled = true
				end
			end)
		}
		if Toggles.AutoLoot.Value then
			Connections.DrawersConnections[drawer].AutoLoot = Services.RunService.RenderStepped:Connect(function()
				if isnetworkowner(main) and not main.Anchored then
					local key = drawer:FindFirstChild("KeyObtain")
					local prompt = key and key:FindFirstChild("ModulePrompt", true)
					if prompt then
						fireproximityprompt(prompt)
					end
					local stardust = drawer:FindFirstChild("Stardust", true)
					local prompt = stardust and stardust:FindFirstChild("ModulePrompt", true)
					if prompt then
						fireproximityprompt(prompt)
					end
					local prompt = drawer:FindFirstChild("ActivateEventPrompt", true)
					if prompt then
						fireproximityprompt(prompt)
					end
				end
			end)
		end
	end

	Toggles.BringDrawers = Groupbox:AddToggle(prefix..'BringDrawers', {
		Text = 'Bring Drawers',
		Default = false,

		Callback = function(value)
			if value then
				toggleNetworkOwner(true)
				if Toggles.OnlyDrawerWithKey.Disabled then
					Toggles.OnlyDrawerWithKey:SetDisabled(false)
				end
				if Toggles.AutoLoot.Disabled then
					Toggles.AutoLoot:SetDisabled(false)
				end
				for _, drawer in CurrentRooms:QueryDescendants("#DrawerContainer") do
					if Toggles.OnlyDrawerWithKey.Value then
							task.spawn(function()
							local key = drawer:WaitForChild("KeyObtain", 1)
							if key then
								log("FOUND KEY IN DRAWER")
								handleDrawer(drawer)
							end
						end)
					else
						handleDrawer(drawer)
					end
				end
				Connections.DrawerAdded = CurrentRooms.DescendantAdded:Connect(function(drawer)
					if drawer.Name == "DrawerContainer" then
						if Toggles.OnlyDrawerWithKey.Value then
							task.wait(.33)
							local key = drawer:WaitForChild("KeyObtain", 1)
							if key then
								log("FOUND KEY IN DRAWER")
								handleDrawer(drawer)
							end
						else
							handleDrawer(drawer)
						end
					end
				end)
			else
				toggleNetworkOwner(false)
				if not Toggles.OnlyDrawerWithKey.Disabled then
					Toggles.OnlyDrawerWithKey:SetDisabled(true)
				end
				if not Toggles.AutoLoot.Disabled then
					Toggles.AutoLoot:SetDisabled(true)
				end
				if Connections.DrawerAdded then
					Connections.DrawerAdded:Disconnect()
					Connections.DrawerAdded = nil
				end
				for drawer, _ in Connections.DrawersConnections or {} do
					task.spawn(disconnectDrawer, drawer)
				end
				Connections.DrawersConnections = nil
			end
		end
	})

	Toggles.AutoLoot = Groupbox:AddToggle(prefix..'AutoLoot', {
		Text = 'Auto Loot',
		Default = false,
		Disabled = true,

		Callback = function()
			if Toggles.BringDrawers.Value then
				Toggles.BringDrawers:SetValue(false)
				task.wait()
				Toggles.BringDrawers:SetValue(true)
			end
		end
	})

	Toggles.OnlyDrawerWithKey = (Floor ~= "Hotel" and Floor ~= "Backdoor" and Floor ~= "Endless" and not (Floor == "Ripple" and FloorSpecific == "Daily_Default")) and {Value = false, Disabled = true, SetDisabled = function(self, value) self.Disabled = value end} or Groupbox:AddToggle(prefix..'OnlyDrawerWithKey', {
		Text = 'Only Drawer With Key',
		Default = false,
		Disabled = true,

		Callback = function()
			if Toggles.BringDrawers.Value then
				Toggles.BringDrawers:SetValue(false)
				task.wait()
				Toggles.BringDrawers:SetValue(true)
			end
		end
	})

	Variables.Decode = require(Services.ReplicatedStorage.NodeObject.MinecartNodes).Decode
	Variables.MinecartTeleport = Library.Toggles.MinecartTeleport
	Toggles.MinecartChaseSkip = (not Variables.MinecartTeleport and {Value = false}) or NoAltFeatures() or Groupbox:AddToggle(prefix..'MinecartChaseSkip', {
		Text = 'Minecart Chase Skip',
		DisabledTooltip = 'Executor is not supported',
		Default = false,
		Disabled = not (hookfunction and Variables.hook and isfunctionhooked and restorefunction),

		Callback = function(value)
			Variables.minecartTp = value
			if value then
				if Variables.MinecartTeleport.Value then
					Variables.MinecartTeleport:SetValue(false)
				end
				Variables.MinecartTeleport:SetDisabled(true)
				local hook; hook = hookfunction(Variables.Decode, function(nodes, folder, start)
					assert(folder, "wheres the folder?!?!") -- yea
					if folder and folder.Parent and (tonumber(folder.Parent.Name) or 0) < 50 then
						return nil
					end
					return hook(nodes, folder, start)
				end)
			else
				Variables.MinecartTeleport:SetDisabled(false)
				if isfunctionhooked and isfunctionhooked(Variables.Decode) then
					restorefunction(Variables.Decode)
				end
			end
		end
	})

	StuffToRemoveLater.partwow = Instance.new("Part")
	StuffToRemoveLater.partwow.Transparency = 1
	StuffToRemoveLater.partwow.Color = Color3.new(1)
	StuffToRemoveLater.partwow.Material = "Glass"
	StuffToRemoveLater.partwow.CanCollide = false
	StuffToRemoveLater.partwow.CanQuery = false
	StuffToRemoveLater.partwow.CanTouch = false
	StuffToRemoveLater.partwow.Anchored = true
	StuffToRemoveLater.partwow.Size = Vector3.new(2,2,1)

	StuffToRemoveLater.highlight = Instance.new("Highlight", StuffToRemoveLater.partwow)
	StuffToRemoveLater.highlight.FillTransparency = .75
	StuffToRemoveLater.highlight.OutlineTransparency = .75
	StuffToRemoveLater.highlight = nil

	local function CreateCoolPart(cframe)
		if not ADDON_CONFIG.Debug then return end
		local supercoolpart = StuffToRemoveLater.partwow:Clone()
		supercoolpart.Parent = workspace
		supercoolpart.CFrame = cframe
		Services.Debris:AddItem(supercoolpart, 3)
	end

	local function getTpFunction()
		local connections = getconnections and getconnections(ServerTeleported.OnClientEvent)
		local connection = connections and connections[1]
		return connection and connection.Function
	end

	Toggles.AntiTeleport = Groupbox:AddToggle(prefix..'AntiTeleport', {
		Text = 'Anti Teleport [UNSTABLE]',
		Tooltip = "Tries to prevent any teleport attempt from server",
		Default = false,
		Risky = true,

		Callback = function(value, yea)
			if value then
				Toggles.AntiTeleportRaknet:SetValue(false)
				Toggles.AntiTeleportRaknet:SetDisabled(true)
				Variables.tpFunction = getTpFunction()
				if hookfunction then
					if Variables.tpFunction then
						local tp; tp = hookfunction(Variables.tpFunction, function(...)
							if checkcaller() then
								tp(...)
							end
						end)
					end
					local hook; hook = hookfunction(ServerTeleported.OnClientEvent.Connect, function(self, func)
						if not checkcaller() then
							hookfunction(func, function()end)
							Variables.tpFunction = func
						end
						return hook(self, func)
					end)
				end
				Connections.AntiTeleportConnection = Services.RunService.Heartbeat:Connect(function()
					local root = Character and Character:FindFirstChild("HumanoidRootPart")
					local human = Character and Character:FindFirstChild("Humanoid")
					if root and human then
						local oldCFrame = root.CFrame
						local oldVelocity = root.AssemblyLinearVelocity
						Services.RunService.Heartbeat:Wait()
						if (oldCFrame.Position-root.Position).Magnitude > human.WalkSpeed/100*2.5 then
							CreateCoolPart(root.CFrame)
							Character:PivotTo(oldCFrame)
							root.AssemblyLinearVelocity = oldVelocity
						end
					end 
				end)
			else
				Toggles.AntiTeleportRaknet:SetDisabled(false)
				if isfunctionhooked and restorefunction then
					if Variables.tpFunction and isfunctionhooked(Variables.tpFunction) then
						restorefunction(Variables.tpFunction)
					end
					if isfunctionhooked(ServerTeleported.OnClientEvent.Connect) then
						restorefunction(ServerTeleported.OnClientEvent.Connect)
					end
				end
				if Connections.AntiTeleportConnection then
					Connections.AntiTeleportConnection:Disconnect()
					Connections.AntiTeleportConnection = nil
				end
				if yea then
					task.spawn(pcall, function()
						Services.RunService.RenderStepped:Wait()
						Toggles.AntiTeleport:SetValue(true)
					end)
				end
			end
		end
	})

	Variables.validPacket = {131, 3}
	local function isPacketValid(packet)
    	for i,v in Variables.validPacket do
        	if v ~= -1 and v ~= packet.AsArray[i] then
        	    return false
        	end
    	end
    	return true
	end

	Variables.confirmed_at = false
	Variables.raknet_at_hook = raknet and raknet.remove_receive_hook and raknet.get_instance_by_id and function(packet)
    	if isPacketValid(packet) then
        	local instance = raknet.get_instance_by_id(1, buffer.readu32(packet.AsBuffer, 3))
        	if instance and instance:IsA("Status") then
        	    local humanoid = instance.Parent
        	    local character = humanoid and humanoid:IsA("Humanoid") and humanoid.Parent
        	    if character and character == Character then
        	        packet:Block()
					Character:PivotTo(Character:GetPivot())
					log("blocked teleport packet")
        	    end
        	end
    	end
	end
	Variables.raknet_at_hooked = false
	Toggles.AntiTeleportRaknet = Groupbox:AddToggle(prefix..'AntiTeleportRaknet', {
		Text = 'Anti Teleport [RAKNET]',
		Tooltip = "Tries to prevent any teleport attempt from server, but with raknet usage",
		DisabledTooltip = not Variables.raknet_at_hook and 'Executor is not supported',
		Disabled = not Variables.raknet_at_hook,
		Default = false,
		Risky = true,

		Callback = function(value, yea)
			if value then
				if not Variables.confirmed_at then
					Variables.confirmed_at = nil
					Window:AddDialog("AntiTeleportRaknetWarning", {
						Title = "WARNING!",
						Description = "This feature can lead to account termination because of raknet library usage, if you still want to use raknet method press Confirm",
						AutoDismiss = true,
						OutsideClickDismiss = true,
						FooterButtons = {
							Cancel = {
								Title = "Cancel",
								Variant = "Primary",
								Order = 1,
								Callback = function()
									Variables.confirmed_at = false
								end
							},
							Confirm = {
								Title = "Confirm",
								Variant = "Destructive",
								WaitTime = 2,
								Order = 2,
								Callback = function(self)
									Variables.confirmed_at = true
								end
							}
						}
					})
					while Variables.confirmed_at == nil do task.wait() end
					if not Variables.confirmed_at then
						Toggles.AntiTeleportRaknet:SetValue(false)
						Toggles.AntiTeleportRaknet:SetDisabled(true)
						task.wait(1)
						Toggles.AntiTeleportRaknet:SetDisabled(false)
						return
					end
				end
				Toggles.AntiTeleport:SetValue(false)
				Toggles.AntiTeleport:SetDisabled(true)
				local success, response = pcall(function()
					raknet.addreceivehook(Variables.raknet_at_hook)
					Variables.raknet_at_hooked = true
				end)
				if not success then
					if response:find("raknet not allowed") or not (raknet.is_enabled and raknet.is_enabled()) then
						Library:Notify({
							Title = Info.AddonTitle.." [Error]",
							Description = 'Raknet is not enabled (enable it in executor settings)',
							Time = 4
						})
					else
						Library:Notify({
							Title = Info.AddonTitle.." [Error]",
							Description = 'Something went wrong while trying to enable Anti Teleport',
							Time = 3
						})
					end
					Toggles.AntiTeleportRaknet:SetValue(false)
					return
				end
				Variables.tpFunction = getTpFunction()
				if hookfunction then
					if Variables.tpFunction then
						local tp; tp = hookfunction(Variables.tpFunction, function(...)
							if checkcaller() then
								tp(...)
							end
						end)
					end
					local hook; hook = hookfunction(ServerTeleported.OnClientEvent.Connect, function(self, func)
						if not checkcaller() then
							hookfunction(func, function()end)
							Variables.tpFunction = func
						end
						return hook(self, func)
					end)
				end
			else
				Toggles.AntiTeleport:SetDisabled(false)
				if isfunctionhooked and restorefunction then
					if Variables.tpFunction and isfunctionhooked(Variables.tpFunction) then
						restorefunction(Variables.tpFunction)
					end
					if isfunctionhooked(ServerTeleported.OnClientEvent.Connect) then
						restorefunction(ServerTeleported.OnClientEvent.Connect)
					end
				end
				if Variables.raknet_at_hooked then
					raknet.removereceivehook(Variables.raknet_at_hook)
					Variables.raknet_at_hooked = false
				end
				if yea then
					task.spawn(pcall, function()
						Services.RunService.RenderStepped:Wait()
						Toggles.AntiTeleportRaknet:SetValue(true)
					end)
				end
			end
		end
	})

	function DoStuffWithAntiTp()
		if Toggles.AntiTeleportRaknet.Value then
			pcall(Toggles.AntiTeleportRaknet.Callback, false, true)
		elseif Toggles.AntiTeleport.Value then
			pcall(Toggles.AntiTeleport.Callback, false, true)
		end
	end

	Variables.walkspeed = 15
	Variables.ladderspeed = 15
	Variables.SpeedHack = Library.Toggles.EnableSpeedHack

	function StartWSConnection()
		Connections.WalkSpeed = Services.RunService.RenderStepped:Connect(function()
			if Character and Character:FindFirstChild("Humanoid") and Character.Parent then
				Character:SetAttribute("SpeedBoostBehind", Variables.ladderspeed-15)
				Character.Humanoid.WalkSpeed = Variables.walkspeed
			end
		end)
	end

	Variables.confirmed_sh = false
	Variables.raknet_sh_hook = raknet and function(packet)
		if packet.PacketId == 0x1B then
			local data = packet.AsBuffer
			buffer.writeu32(data, 1, 0xFFFFFFFF)
			buffer.writeu32(data, 2, 0xFFFFFFFF)
			packet:SetData(data)
		end
	end
	Variables.raknet_sh_hooked = false
	Toggles.RakNetSpeedHack = Groupbox:AddToggle(prefix..'RakNetSpeedHack', {
		Text = 'SpeedHack RakNet method',
		Tooltip = "I dont recommend you to use this feature, try speedhack slide method instead",
		DisabledTooltip = Variables.raknet_sh_hook and 'Please wait...' or 'Executor is not supported',
		Disabled = not Variables.raknet_sh_hook,
		Default = false,
		Risky = true,

		Callback = function(value)
			if value then
				if not Variables.confirmed_sh then
					Variables.confirmed_sh = nil
					Window:AddDialog("RakNetSpeedHackWarning", {
						Title = "WARNING!",
						Description = "This feature can lead to account termination because of raknet library usage, if you still want to use raknet method press Confirm",
						AutoDismiss = true,
						OutsideClickDismiss = true,
						FooterButtons = {
							Cancel = {
								Title = "Cancel",
								Variant = "Primary",
								Order = 1,
								Callback = function()
									Variables.confirmed_sh = false
								end
							},
							Confirm = {
								Title = "Confirm",
								Variant = "Destructive",
								WaitTime = 2,
								Order = 2,
								Callback = function(self)
									Variables.confirmed_sh = true
								end
							}
						}
					})
					while Variables.confirmed_sh == nil do task.wait() end
					if not Variables.confirmed_sh then
						Toggles.RakNetSpeedHack:SetValue(false)
						Toggles.RakNetSpeedHack:SetDisabled(true)
						task.wait(1)
						Toggles.RakNetSpeedHack:SetDisabled(false)
						return
					end
				end
				if Variables.SpeedHack.Value then
					pcall(Variables.SpeedHack.SetValue, Variables.SpeedHack, false)
				end
				pcall(Variables.SpeedHack.SetDisabled, Variables.SpeedHack, true)
				if Toggles.SlideSpeedHack.Value then
					Toggles.SlideSpeedHack:SetValue(false)
				end
				Toggles.SlideSpeedHack:SetDisabled(true)
				Toggles.RakNetSpeedHack:SetDisabled(true)
				local success, response = pcall(function()
					raknet.addsendhook(Variables.raknet_sh_hook)
					Variables.raknet_sh_hooked = true
				end)
				if not success then
					if response:find("raknet not allowed") or not (raknet.is_enabled and raknet.is_enabled()) then
						Library:Notify({
							Title = Info.AddonTitle.." [Error]",
							Description = 'Raknet is not enabled (enable it in executor settings)',
							Time = 4
						})
					else
						Library:Notify({
							Title = Info.AddonTitle.." [Error]",
							Description = 'Something went wrong while trying to load Speed Bypass',
							Time = 3
						})
					end
					Toggles.RakNetSpeedHack:SetDisabled(false)
					Toggles.RakNetSpeedHack:SetValue(false)
					return
				end
				StartWSConnection()
				Character:PivotTo(CFrame.new(0,1500000,0))
				Library:Notify({
					Title = Info.AddonTitle,
					Description = 'Speed bypass is loading, please wait...',
					Time = 3
				})
				while Character.Collision.Position.Y > 1000000 do
					Character.Collision.AssemblyLinearVelocity = Vector3.new(0,0,0)
					Services.RunService.RenderStepped:Wait()
				end
				Toggles.RakNetSpeedHack:SetDisabled(false)
				Library:Notify({
					Title = Info.AddonTitle,
					Description = 'Speed bypass loaded',
					Time = 2
				})
			else
				if Variables.raknet_sh_hooked then
					raknet.removesendhook(Variables.raknet_sh_hook)
					Variables.raknet_sh_hooked = false
				end
				if Connections.WalkSpeed then
					Connections.WalkSpeed:Disconnect()
				end
				Character:SetAttribute("SpeedBoostBehind", 0)
				Character.Humanoid.WalkSpeed = 15
				pcall(Variables.SpeedHack.SetDisabled, Variables.SpeedHack, false)
				Toggles.SlideSpeedHack:SetDisabled(false)
			end
		end
	})

	Toggles.SlideSpeedHack = NoAlrAddedFeatures() or Groupbox:AddToggle(prefix..'SlideSpeedHack', {
		Text = 'Speed (Slide Bypass)',
		Tooltip = "Already in mspaint (speed bypass method discovered by @nahhthatscrazy)",
		Default = Variables.slideSH,

		Callback = function(value)
			if value then
				Variables.slideSH = true
				if Variables.SpeedHack.Value then
					pcall(Variables.SpeedHack.SetValue, Variables.SpeedHack, false)
				end
				pcall(Variables.SpeedHack.SetDisabled, Variables.SpeedHack, true)
				if Toggles.RakNetSpeedHack.Value then
					Toggles.RakNetSpeedHack:SetValue(false)
				end
				Toggles.RakNetSpeedHack:SetDisabled(true)
				StartWSConnection()
				if Variables.hook then
					Crouch:FireServer(Character:GetAttribute("Crouching"), true)
				else
					while Variables.slideSH do
						Crouch:FireServer(Character:GetAttribute("Crouching"), true)
						task.wait()
					end
				end
			else
				Variables.slideSH = false
				if Connections.WalkSpeed then
					Connections.WalkSpeed:Disconnect()
				end
				Character:SetAttribute("SpeedBoostBehind", 0)
				Character.Humanoid.WalkSpeed = 15
				pcall(Variables.SpeedHack.SetDisabled, Variables.SpeedHack, false)
				Toggles.RakNetSpeedHack:SetDisabled(not raknet)
			end
		end
	})

	Groupbox:AddSlider(prefix.."TWalkSpeed", {
		Text = "Speed",
		Default = Variables.walkspeed,
		Min = 0,
		Max = 150,
		Rounding = 0,
		Compact = true,
		Callback = function(ws)
			local aboveLimit = ws > 100
            local shouldWarn = aboveLimit and not Variables.MrHSpeedWarningActive
            Variables.MrHSpeedWarningActive = aboveLimit
            Variables.walkspeed = ws
            if shouldWarn then
                Library:Notify({
                    Title = "Speed Warning",
                    Description = "This may be buggy,use it carefully",
                    Time = 6,
                })
            end
		end
	})

	Groupbox:AddSlider(prefix.."TLadderSpeed", {
		Text = "Ladder Speed",
		Default = Variables.ladderspeed,
		Min = 0,
		Max = 75,
		Rounding = 0,
		Compact = true,
		Callback = function(ls)
			Variables.ladderspeed = ls
		end
	})

	Groupbox:AddDivider({
		Margin = -3
	})

	Variables.reviveGhost1 = Groupbox:AddButton(prefix..'ReviveAsGhost1', {
		Text = 'Revive As Ghost',
		Tooltip = "Need to be executed at door 0, works like fake revive but its way more stable and doesn't break after any cutscene\nAfter any cutscene anticheat bypass stops working (but you'll be still invincible)\nTo interact with coins, stardust, closets, drawers and etc. you need to get heal from something",
		DisabledTooltip = not (require and replicatesignal and fireproximityprompt and firetouchinterest) and 'Executor is not supported' or 'Better Fake Death is already executed',
		DoubleClick = true,
		Disabled = not (require and replicatesignal and fireproximityprompt and firetouchinterest) or LocalPlayer:GetAttribute("_GhostRevived"),

		Func = function()
			if OpenedFirstDoor.Value then
				Library:Notify({
					Title = Info.AddonTitle.." [Error]",
					Description = "The first door was opened, this method won't work anymore",
					Time = 3
				})
				return
			elseif Floor == "Mines" then
				Library:Notify({
					Title = Info.AddonTitle.." [Error]",
					Description = "This method doesn't work in mines",
					Time = 2
				})
				return
			end
			Variables.reviveGhost1:SetDisabled(true)
			Variables.reviveGhost2:SetDisabled(true)
			Library:Notify({
				Title = Info.AddonTitle,
				Description = 'Please wait...',
				Time = 2
			})
			local deadCharacter
			local lock = false
			local room = CurrentRooms:GetChildren()[1]
			local door = room and room.Door
			if door:FindFirstChild("Lock") then
				lock = true
			elseif not door then
				Library:Notify({
					Title = Info.AddonTitle.." [Error]",
					Description = "Failed to find the door",
					Time = 2
				})
				return
			end
			task.spawn(function()
				while not deadCharacter do
					Crouch:FireServer(nil,true)
					task.wait()
				end
			end)
			local key = lock and (Character:FindFirstChild("Key") or LocalPlayer.Backpack:FindFirstChild("Key"))
			if lock and not key then
				local keyObtain = room.Assets.KeyObtain
				Character:PivotTo(keyObtain.Hitbox.CFrame)
				fireproximityprompt(keyObtain.ModulePrompt)
				key = Character:FindFirstChild("Key") or LocalPlayer.Backpack:FindFirstChild("Key")
				while not key do
					task.wait()
					Character:PivotTo(keyObtain.Hitbox.CFrame)
					fireproximityprompt(keyObtain.ModulePrompt)
					key = Character:FindFirstChild("Key") or LocalPlayer.Backpack:FindFirstChild("Key")
				end
				key.Parent = Character
			elseif key then
				key.Parent = Character
			end
			local Delay = os.clock()
			RequestLocalAsset:InvokeServer({{}})
			Delay = os.clock()-Delay
			deadCharacter = Character
			replicatesignal(LocalPlayer.Kill)
			task.wait(math.clamp(Delay-.01, 0, 1/0))
			if lock then
				task.spawn(function()
					deadCharacter:PivotTo(door.Door.CFrame)
					if door.Lock:FindFirstChild("UnlockPrompt") then
						fireproximityprompt(door.Lock.UnlockPrompt)
					else
						for _, prompt in workspace:FindFirstChild("Folder") and workspace.Folder:GetChildren() or {} do
							if prompt:IsA("ProximityPrompt") and prompt.Name == "UnlockPrompt" then
								fireproximityprompt(prompt) -- thanks mspaint devs for making my life harder and placing unlockprompt into folder that was created my mspaint
							end
						end
					end
					while deadCharacter.Parent do
						task.wait()
						deadCharacter:PivotTo(door.Door.CFrame)
						if door.Lock:FindFirstChild("UnlockPrompt") then
							fireproximityprompt(door.Lock.UnlockPrompt)
						else
							for _, prompt in workspace:FindFirstChild("Folder") and workspace.Folder:GetChildren() or {} do
								if prompt:IsA("ProximityPrompt") and prompt.Name == "UnlockPrompt" then
									fireproximityprompt(prompt)
								end
							end
						end
					end
				end)
			else
				task.spawn(function()
					local emptyPart = Instance.new("Part")
					deadCharacter.HumanoidRootPart.CFrame = (door:FindFirstChild("Collision") or door:FindFirstChild("Hidden") or emptyPart).CFrame
					firetouchinterest(deadCharacter.HumanoidRootPart, door:FindFirstChild("Collision") or door:FindFirstChild("Hidden") or emptyPart, 0)
					firetouchinterest(deadCharacter.HumanoidRootPart, door.Collision, 1)
					while deadCharacter.Parent do
						task.wait()
						deadCharacter.HumanoidRootPart.CFrame = (door:FindFirstChild("Collision") or door:FindFirstChild("Hidden") or emptyPart).CFrame
						firetouchinterest(deadCharacter.HumanoidRootPart, door:FindFirstChild("Collision") or door:FindFirstChild("Hidden") or emptyPart, 0)
						firetouchinterest(deadCharacter.HumanoidRootPart, door:FindFirstChild("Collision") or door:FindFirstChild("Hidden") or emptyPart, 1)
					end
					emptyPart:Destroy()
				end)
			end
			local character
			task.spawn(function()
				character = LocalPlayer.CharacterAdded:Wait()
			end)
			replicatesignal(LocalPlayer.Kill)
			while not character and task.wait() do
				replicatesignal(LocalPlayer.Kill)
			end
			if not OpenedFirstDoor.Value then
				reviveGhost1:SetDisabled(false)
				reviveGhost2:SetDisabled(false)
				Library:Notify({
					Title = Info.AddonTitle.." [Error]",
					Description = 'Failed to open the first door, trying again...',
					Time = 3
				})
				task.wait(.1)
				reviveGhost1.Func()
				return
			end
			LocalPlayer:SetAttribute("Alive", true)
			LocalPlayer:GetAttributeChangedSignal("Alive"):Connect(function()
				LocalPlayer:SetAttribute("Alive", true)
			end)
			LocalPlayer:SetAttribute("_GhostRevived", true)
			local humanoid = character:WaitForChild("Humanoid", 9e9)
			local function nodead()
				pcall(humanoid.SetStateEnabled, humanoid, Enum.HumanoidStateType.Dead, false) -- if i do it using humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false) for some reason humanoid will turn into a CoreGui.Obsidian.Frame.Frame
			end
			nodead()
			Services.RunService.RenderStepped:Connect(nodead)
			if _hookmetamethod then
				local oi; oi = _hookmetamethod(humanoid, "__index", function(self, key)
					if not checkcaller() and self == humanoid and key == "Health" then
						local maxhealth = humanoid.MaxHealth
						return maxhealth <= 0 and 1 or maxhealth
					end
					return oi(self, key)
				end)
				local oni; oni = _hookmetamethod(humanoid, "__newindex", function(self, key, new)
					if not checkcaller() and self == humanoid and key == "Health" then
						local maxhealth = humanoid.MaxHealth
						new = maxhealth <= 0 and 1 or maxhealth
					end
					return oni(self, key, new)
				end)
			else
				humanoid.Health = 100
				humanoid:GetPropertyChangedSignal("Health"):Connect(function()
					nodead()
					humanoid.Health = 100
				end)
			end
			if hookfunction and filtergc then
				hookfunction(GetFunction("healthChanged") or function() end, function() end)
			end
			Library:Notify({
				Title = Info.AddonTitle,
				Description = 'Successfully revived as ghost',
				Time = 3
			})
		end
	})

	Variables.reviveGhost2 = Groupbox:AddButton(prefix..'ReviveAsGhost2', {
		Text = 'Revive As Ghost',
		Tooltip = "Requires at least 1 revive, works like fake revive but its way more stable and doesn't break after any cutscene\nThis feature can sometimes waste your revive + after any cutscene anticheat bypass stops working (but you'll be still invincible)\nTo interact with coins, stardust, closets, drawers and etc. you need to get heal from something",
		DisabledTooltip = not (require and replicatesignal) and 'Executor is not supported' or 'Better Fake Death is already executed',
		DoubleClick = true,
		Disabled = not (require and replicatesignal) or LocalPlayer:GetAttribute("_GhostRevived"),

		Func = function()
			local data = Services.ReplicatedStorage:FindFirstChild("ReplicaDataModule") and require(Services.ReplicatedStorage.ReplicaDataModule)
			if Floor ~= "Hotel" and Floor ~= "Mines" then
				Library:Notify({
					Title = Info.AddonTitle.." [Error]",
					Description = "This method doesn't work in subfloors",
					Time = 3
				})
				return
			elseif not OpenedFirstDoor.Value then
				Library:Notify({
					Title = Info.AddonTitle.." [Error]",
					Description = 'Please open the first door',
					Time = 2
				})
				return
			elseif not (data and data.data) or (data.data.Revives or 0) <= 0 then
				Library:Notify({
					Title = Info.AddonTitle.." [Error]",
					Description = 'You need at least 1 revive',
					Time = 3
				})
				return
			end
			Variables.reviveGhost1:SetDisabled(true)
			Variables.reviveGhost2:SetDisabled(true)
			Library:Notify({
				Title = Info.AddonTitle,
				Description = 'Please wait...',
				Time = 2
			})
			replicatesignal(LocalPlayer.Kill)
			task.wait(3)
			local character
			task.spawn(function()
				character = LocalPlayer.CharacterAdded:Wait()
			end)
			Revive:FireServer()
			replicatesignal(LocalPlayer.Kill)
			while not character and task.wait() do
				replicatesignal(LocalPlayer.Kill)
			end
			LocalPlayer:SetAttribute("Alive", true)
			LocalPlayer:GetAttributeChangedSignal("Alive"):Connect(function()
				LocalPlayer:SetAttribute("Alive", true)
			end)
			LocalPlayer:SetAttribute("_GhostRevived", true)
			local humanoid = character:WaitForChild("Humanoid", 9e9)
			local function nodead()
				pcall(humanoid.SetStateEnabled, humanoid, Enum.HumanoidStateType.Dead, false) -- if i do it using humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false) for some reason humanoid will turn into a CoreGui.Obsidian.Frame.Frame
			end
			nodead()
			Services.RunService.RenderStepped:Connect(nodead)
			if _hookmetamethod then
				local oi; oi = _hookmetamethod(humanoid, "__index", function(self, key)
					if not checkcaller() and self == humanoid and key == "Health" then
						return 100
					end
					return oi(self, key)
				end)
				local oni; oni = _hookmetamethod(humanoid, "__newindex", function(self, key, new)
					if not checkcaller() and self == humanoid and key == "Health" then
						new = 100
					end
					return oni(self, key, new)
				end)
			else
				humanoid.Health = 100
				humanoid:GetPropertyChangedSignal("Health"):Connect(function()
					nodead()
					humanoid.Health = 100
				end)
			end
			if hookfunction and filtergc then
				hookfunction(GetFunction("healthChanged") or function() end, function() end)
			end
			Library:Notify({
				Title = Info.AddonTitle,
				Description = 'Successfully revived as ghost',
				Time = 3
			})
		end
	})

	function SetMethod(value)
		Variables.reviveGhost1:SetVisible(value == "Method #1")
		Variables.reviveGhost2:SetVisible(value == "Method #2")
	end

	local dropdown = Groupbox:AddDropdown(prefix..'GhostReviveMethod', {
		Text = 'Method',
		Values = {
			"Method #1",
			"Method #2",
		},
		Default = "Method #1",
		Callback = SetMethod
	})

	SetMethod(dropdown.Value)

	Groupbox2:AddDivider({
		Text = "QOL",
		MarginTop = 2,
		MarginBottom = -2
	})

	Toggles.Freecam = Groupbox2:AddToggle(prefix..'Freecam', {
		Text = 'Freecam',
		DisabledTooltip = 'Executor is not supported',
		Default = false,
		Disabled = not (firesignal or require),

		Callback = function(value)
			required_main_game.noclip = value
			required_main_game.freecam = value
			required_main_game.hideplayers = value and -1 or 0
		end
	})

	Groupbox2:AddDivider({
		Margin = -6
	})

	Toggles.NoWardrobeVignette = Groupbox2:AddToggle(prefix..'NoWardrobeVignette', {
		Text = 'No Wardrobe Vignette',
		Default = false,

		Callback = function(value)
			local vignette = PlayerGui.MainUI.MainFrame.HideVignette
			if value then
				vignette.Size = UDim2.new(0,0,0,0)
			else
				vignette.Size = UDim2.new(1,0,1,0)
			end
		end
	})

	Toggles.RemoveAmbience = Groupbox2:AddToggle(prefix..'RemoveAmbience', {
		Text = 'No Random Ambience',
		Default = false,

		Callback = function(value)
			if value then
				Connections.RemoveAmbience = workspace.Terrain.ChildAdded:Connect(function(child)
					if child:IsA('Attachment') then
						child:Destroy()
					end
				end)
			else
				if not Connections.RemoveAmbience then return end
				Connections.RemoveAmbience:Disconnect()
			end
		end
	})

	Toggles.AntiGreenEffect = Groupbox2:AddToggle(prefix..'AntiGreenEffect', {
		Text = 'Anti Gween Soda Effect',
		Default = false,

		Callback = function(value)
			if value then
				if Camera:FindFirstChild("Im green... No... NOOO!!!!") then
					Camera["Im green... No... NOOO!!!!"]:Destroy()
				end
				Connections.OnGreenEffectAdded = Camera.ChildAdded:Connect(function(child)
					if child.Name == "Im green... No... NOOO!!!!" then
						child:Destroy()
					end
				end)
			elseif Connections.OnGreenEffectAdded then
				Connections.OnGreenEffectAdded:Disconnect()
				Connections.OnGreenEffectAdded = nil
			end
		end
	})

	Variables.EndingCutscene = Floor == "Hotel" and "Elevator1" or Floor == "Mines" and "MinesFinale" or Floor == "Garden" and "GardenEnding"
	if Variables.EndingCutscene then
		Toggles.FastEnding = Groupbox2:AddToggle(prefix.."FastEnding", {
			Text = "Fast Ending",
			Tooltip = "Get rewards right after you finished the floor",
			Default = false,

			Callback = function(value)
				if value then
					Connections.OnCutsceneFPA = Cutscene.OnClientEvent:Connect(function(name)
						if name == Variables.EndingCutscene then
							task.wait(.1)
							Statistics:FireServer()
						end
					end)
				else
					if Connections.OnCutsceneFPA then
						Connections.OnCutsceneFPA:Disconnect()
					end
				end
			end
		})
	end

	Toggles.NoReviveCutscene = Groupbox2:AddToggle(prefix..'NoReviveCutscene', {
		Text = 'No Revive Cutscene',
		Default = false,

		Callback = function(value)
			Variables.noReviveCutscene = value
		end
	})

	Toggles.NoMedalAutoclip = Groupbox2:AddToggle(prefix..'NoMedalAutoclip', {
		Text = 'No Medal Autoclip',
		DisabledTooltip = 'Executor is not supported',
		Tooltip = 'Disables Medal autoclip when you die to someone or complete the game (you can disable autoclip for roblox in medal settings, made this feature just for testing)',
		Default = false,
		Disabled = not hookfunction or not restorefunction,

		Callback = function(value)
			if value then
				local realPrint; realPrint = hookfunction(print, function(...)
					local args = {...}
					if not checkcaller() and args[1] == "[_MAPIEvent][v1/event/invoke]" then
						local success, result = pcall(function()
							return Services.HttpService:JSONDecode(decodeBase64(args[2]))
						end)
						result = success and result
						if result and typeof(result.triggerActions) == "table" and table.find(result.triggerActions, "SaveClip") then
							return
						end
					end
					return realPrint(...)
				end)
			else
				if isfunctionhooked(print) then
					restorefunction(print)
				end
			end
		end
	})

	Variables.ClientFuncRemote = Services.ReplicatedStorage:FindFirstChild("FloorReplicated")
	Variables.ClientFuncRemote = Variables.ClientFuncRemote and Variables.ClientFuncRemote:FindFirstChild("ClientRemote")
	Variables.ClientFuncRemote = Variables.ClientFuncRemote and Variables.ClientFuncRemote:FindFirstChild("StreamVoteClientFunction")
	Variables.ClientFuncRemote = Variables.ClientFuncRemote and Variables.ClientFuncRemote:FindFirstChild("Remote")
	Variables.currentFuncToHook = Variables.ClientFuncRemote and getconnections(Variables.ClientFuncRemote.OnClientEvent)[1].Function
	Toggles.NoRandomClientEvents = not Variables.ClientFuncRemote and {Value = false} or Groupbox2:AddToggle(prefix..'NoRandomClientEvents', {
		Text = 'No Random Client Events',
		DisabledTooltip = 'Executor is not supported',
		Tooltip = 'Disables all random client events (Chaos Mode)',
		Default = false,
		Disabled = not (hookfunction and restorefunction),

		Callback = function(value)
			if value then
				local randomConnect, randomConnect = hookfunction(Variables.ClientFuncRemote.OnClientEvent.Connect, function(self, func)
					if not checkcaller() then
						hookfunction(func, function()end)
						currentFuncToHook = func
					end
					return randomConnect(self, func)
				end)
			else
				if Variables.ClientFuncRemote and isfunctionhooked(Variables.ClientFuncRemote.OnClientEvent and Variables.ClientFuncRemote.OnClientEvent.Connect or function()end) then
					restorefunction(Variables.ClientFuncRemote.OnClientEvent.Connect)
				end
				if isfunctionhooked(Variables.currentFuncToHook or function()end) then
					restorefunction(Variables.currentFuncToHook)
				end
			end
		end
	})

	Groupbox2:AddDivider({
		Margin = -6
	})

	function rn2ht(c)
		return 10+(10/3-10)*c/100
	end

	function update(arg)
		if Variables.annoying_notification then
			if Floor == "Hotel" then
				Variables.annoying_notification:ChangeDescription(`Current hide time: {arg==50 and 20 or arg==100 and "Infinite" or math.clamp(math.round((rn2ht(arg)+(arg>=90 and 1.2 or 0))*1000)/1000, -1/0, isModifierEnabled("HideTime") and 4 or 1/0)}`)
			elseif Floor == "Mines" then
				Variables.annoying_notification:ChangeDescription(`Current hide time: {math.clamp(math.round((rn2ht(arg)+(arg>=61 and 1.4 or 0))*1000)/1000, -1/0, isModifierEnabled("HideTime") and 4 or 1/0)}`)
			end
		end
	end

	Toggles.CurrentHideTime = Floor ~= "Hotel" and Floor ~= "Mines" and {Value = false} or Groupbox2:AddToggle(prefix..'CurrentHideTime', {
		Text = 'Current Hide Time',
		Default = false,

		Callback = function(value)
			if value then
				Variables.annoying_notification = Library:Notify({
					Title = Info.AddonTitle,
					Description = 'Current hide time: ?',
					Persist = true
				})
				update(LatestRoom.Value)
				Connections.HideTimeChanged = CurrentRooms.ChildAdded:Connect(function(child)
					update(LatestRoom.Value)
				end)
			else
				if Variables.annoying_notification then
					Variables.annoying_notification:Destroy()
				end
				if Connections.HideTimeChanged then
					Connections.HideTimeChanged:Disconnect()
				end
			end
		end
	})

	Toggles.HidingRoomNotify = Groupbox2:AddToggle(prefix..'HidingRoomNotify', {
		Text = 'Hiding Room Notify',
		Tooltip = 'May predict when Rush or Ambush will spawn',
		Default = false,

		Callback = function(value)
			if value then
				Connections.EntityPrediction = CurrentRooms.ChildAdded:Connect(function(child)
					if child:GetAttribute('HidingRoom') and not workspace:FindFirstChild('RushMoving') and not workspace:FindFirstChild('AmbushMoving') then
						Library:Notify({
							Title = Info.AddonTitle,
							Description = 'Next room is a hiding room',
							Time = 2
						})
					end
				end)
			else
				if not Connections.EntityPrediction then return end
				Connections.EntityPrediction:Disconnect()
			end
		end
	})

	Groupbox2:AddDivider({
		Margin = -6
	})

	task.spawn(function()
		Variables.CARRemote = Services.ReplicatedStorage:WaitForChild("ClientAnimationReceiver", 1/0):WaitForChild("RemoteEvent", 1/0)
	end)

	Toggles.GSNotifier = Groupbox2:AddToggle(prefix..'GSNotifier', {
		Text = 'Groundskeeper Notifier',
		DisabledTooltip = 'Please wait...',
		Tooltip = 'Get notification when Groundskeeper wants to kill or killed somebody',
		Default = false,
		Disabled = not Variables.CARRemote,
	})

	function playerName(player)
		return `{player.DisplayName}{player.DisplayName == player.Name and "" or ` (@{player.Name})`}`
	end

	function getNameFromPartInLookAtAction(part)
		local player = part and part.Parent and Services.Players:GetPlayerFromCharacter(part.Parent)
		if player then
			return playerName(player)
		elseif part and part.Name == "Root" and part.Parent and part.Parent.Name == "Mandrake" then
			return "Mandrake"
		else
			return "Someone"
		end
	end

	task.spawn(function()
		while not Variables.CARRemote do
			task.wait()
		end
		Toggles.GSNotifier:SetDisabled(false)
		Connections.GroundskeeperWatcher = Variables.CARRemote.OnClientEvent:Connect(function(action, _, name, part)
			if not Toggles.GSNotifier.Value then return end
			if action == "ClientAction" and name == "LookAt" then
				Variables.lastLookAt = part
			elseif action == "PlayAnimation" then
				if name == "start_sprint" then
					Variables.sprintTo = Variables.lastLookAt
					Library:Notify({
						Title = Info.AddonTitle.." [Groundskeeper]",
						Description = `Groundskeeper is sprinting to {getNameFromPartInLookAtAction(Variables.lastLookAt)}!`,
						Time = 3,
					})
				elseif name == "end_sprint" then
					Library:Notify({
						Title = Info.AddonTitle.." [Groundskeeper]",
						Description = sprintTo and `Groundskeeper doesn't sprint to {getNameFromPartInLookAtAction(Variables.sprintTo)} now` or "Groundskeeper doesn't sprint now",
						Time = 3,
					})
					Variables.sprintTo = nil
				elseif name == "crucifix" then
					Library:Notify({
						Title = Info.AddonTitle.." [Groundskeeper]",
						Description = `Someone used crucifix on Groundskeeper, wtf?????`,
						Time = 3,
					})
					Variables.sprintTo = nil
				end
			elseif action == "StopAllAnimations" and not Variables.lastLookAt and Variables.sprintTo then
				Library:Notify({
					Title = Info.AddonTitle.." [Groundskeeper]",
					Description = `{getNameFromPartInLookAtAction(Variables.sprintTo)} was killed by Groundskeeper`,
					Time = 3,
				})
				Variables.sprintTo = nil
			end
		end)
	end)

	Variables.MonumentNotifier = false
	Toggles.MonumentNotifier = Groupbox2:AddToggle(prefix..'MonumentNotifier', {
		Text = 'Monument Notifier',
		Tooltip = 'Get notification when Monument killed somebody',
		Default = false,

		Callback = function(value)
			Variables.MonumentNotifier = Value
		end
	})

	Connections.MonumentWatcher = ReplicateAnimation.OnClientEvent:Connect(function(character, animation)
		if character ~= Character and Variables.MonumentNotifier then
			local player = Services.Players:GetPlayerFromCharacter(character)
			local isMonumentAnim = animation.Parent and animation.Parent.Name == "MonumentClient"
			if player and isMonumentAnim and animation.Name == "KillPlayerAnimation" then
				Library:Notify({
					Title = Info.AddonTitle.." [Monument]",
					Description = `{playerName(player)} was killed by Monument`,
					Time = 3,
				})
			end
		end
	end)

	Groupbox2:AddDivider({
		Margin = -6
	})

	Variables.betterObtain = false
	Variables.currentFunction = getcallbackvalue or getcallbackvalue(ObtainGiftedRevive, "OnClientInvoke") or function(...)end
	Variables.obtain = hookmetamethod and hookmetamethod(game, "__newindex", function(...)
		local self, key, originalFunc = ...
		if not checkcaller() and self == ObtainGiftedRevive and key == "OnClientInvoke" then
			if Variables.betterObtain then
				hookfunction(originalFunc, OnReviveObtain)
			end
			Variables.currentFunction = originalFunc
		end
		return Variables.obtain(...)
	end)

	Toggles.BetterRevivesObtain = Groupbox2:AddToggle(prefix..'BetterRevivesObtain', {
		Text = 'Better Revives Obtain',
		DisabledTooltip = 'Executor is not supported',
		Tooltip = 'Lets you keep revives that players gifted you and receive multiple revive gifts without doors cancelling them',
		Default = Variables.betterObtain,
		Disabled = not (Variables.obtain and restorefunction),

		Callback = function(value)
			Variables.betterObtain = value
			local success, hooked = pcall(isfunctionhooked, Variables.currentFunction)
			hooked = success and hooked
			if value and not hooked then
				hookfunction(Variables.currentFunction, OnReviveObtain)
			elseif not value and hooked then
				restorefunction(Variables.currentFunction)
			end
			task.spawn(function()
				if Variables.disableGifting then
					Toggles.DisableReviveGifting:SetValue(false)
				end
				Toggles.DisableReviveGifting:SetDisabled(not value)
				Variables.disableGifting = false
			end)
		end
	})

	Toggles.DisableReviveGifting = Groupbox2:AddToggle(prefix..'DisableReviveGifting', {
		Text = 'Disable Revive Gifting',
		Tooltip = 'Prevent players from gifting you revives',
		Default = false,
		Disabled = true,

		Callback = function(value)
			Variables.disableGifting = value
		end
	})

	Variables.adminLoaded = false

    if not isModifierEnabled("AdminPanel") then
        Groupbox2:AddButton(prefix.."LoadDEVPanelUnavailable", {
            Text = "Load DEV panel",
            Disabled = true,
            DisabledTooltip = "Requires the game's Admin Panel modifier. This addon cannot grant server admin permissions.",
            Func = function() end,
        })
    end

	if isModifierEnabled("AdminPanel") then
		local hook2; hook2 = hookmetamethod and hookmetamethod(game, '__index', function(...)
			local self, key = ...
			if self == game and key == 'GameId' and not checkcaller() and Variables.adminLoaded then
				return 3833818265
			end
			return hook2(...)
		end)

		Variables.admin = PlayerGui:FindFirstChild('DoorsAdmin')
		local Event = RemotesFolder.AdminPanelRunCommand
		local Stuff = {}

		function SetDisabled(bool)
			for name, stuff in Stuff do
				stuff:SetDisabled(bool)
			end
		end

		PlayerGui.ChildAdded:Connect(function(child)
			if child.Name == 'DoorsAdmin' and not admin then
				Variables.admin = child
				SetDisabled(false)
				Stuff.AdminPanelDebug:SetDisabled(false)
				Variables.admin.AncestryChanged:Once(function()
					Variables.admin = PlayerGui:FindFirstChild("DoorsAdmin")
					Variables.adminLoaded = not not Variables.admin
					SetDisabled(not Variables.admin)
				end)
			end
		end)

		Groupbox2:AddDivider({
			Text = "ADMIN PANEL",
			MarginTop = 2,
			MarginBottom = -2
		})

		Stuff.AdminPanelDebug = Groupbox2:AddButton(prefix..'AdminPanelDebug', {
			Text = 'Load DEV panel',
			DisabledTooltip = 'Requires the game Admin Panel modifier and an available DoorsAdmin panel',
			Tooltip = 'Loads tplay debug and developer controls into the existing Admin Panel',
			DoubleClick = true,
			Disabled = not Variables.admin,
			Func = function()
				if Variables.adminLoaded then return end
				Stuff.AdminPanelDebug:SetDisabled(true)
				Variables.adminLoaded = true
				ItemsFromAddon = {}
				LocalPlayer:SetAttribute('ServerAdmin', 4)
				function AddItem(item, name, icon)
					if Variables.admin.AdminPanel.Items:FindFirstChild(item) then
						logprint(item, "already exist")
						return
					end
					local itemFolder = Instance.new('Folder', Variables.admin.AdminPanel.Items)
					itemFolder.Name = item
					itemFolder:SetAttribute('DisplayName', `{name} [unavailable]`)
					itemFolder:SetAttribute('Image', icon)
					ItemsFromAddon[#ItemsFromAddon+1] = itemFolder
				end
				AddItem('Stem', 'Stem', 'rbxassetid://80334088426896')
				AddItem('SecretCD', 'Disc', 'rbxassetid://102651623741266')
				AddItem('CartPushTool', 'CartPushTool', 'rbxassetid://14098615241')
				AddItem('GweenSodaPack', 'Pack of Gween Soda', 'rbxassetid://75397946540493')
				AddItem('LargeScrew', 'Large Screw', 'rbxassetid://108745295669342')
				AddItem('BrokenMonitor', 'Broken Monitor', 'rbxassetid://122841415160190')
				AddItem('JerryCan', 'Jerry Can', 'rbxassetid://112188613409282')
				AddItem('DinkyLamp', 'Lamp', 'rbxassetid://94390736027821')
				AddItem('AbrahamHat', 'Damaged Hat', 'rbxassetid://127613603093961')
				AddItem('BottleCrate', 'Crate of Bottles', 'rbxassetid://128967620334283')
				AddItem('Flares', 'Flare', 'rbxassetid://131318338880701')
				AddItem('Briefcase', 'Briefcase', 'rbxassetid://138634158890068')
				AddItem('HoneyPot', 'Honey Pot', 'rbxassetid://84825411467075')
				AddItem('PaperPlane', 'Paper Plane', 'rbxassetid://80334088426896')
				AddItem('WaterCup', 'Water Cup', 'rbxassetid://71060879079691')
				AddItem('ArchivesTicket', 'Ticket', 'rbxassetid://116552699534329')
				AddItem('FihFlakes', 'Fih Flakes', 'rbxassetid://121885940364750')
				AddItem('HonchoCoffee', 'Honcho Mug', 'rbxassetid://99451032775084')
				AddItem('SallyToy', 'Sally\'s Toy', 'rbxassetid://126510979761292')
				AddItem('CartToGo', 'Cart-to-Go', 'rbxassetid://81829195761498')
				AddItem('Candy', 'Candy', 'rbxassetid://91226846785149')
				AddItem('CandyBag', 'Candy Bag', 'rbxassetid://88108365460057')
				AddItem('Buddy', 'Buddy', 'rbxassetid://96164691124017')
				AddItem('Lotus', 'Lotus', 'rbxassetid://121905075599624')
				AddItem('LotusPetal', 'Lotus Petal', 'rbxassetid://82584389669499')
				AddItem('Scanner', 'NVCS-3000', 'rbxassetid://11374263930')
				Variables.admin.AdminPanel.PanelClient.Enabled = false
				Variables.admin.Container.Pages:ClearAllChildren()
				local lol = Variables.admin.Container.TabButtons.UIListLayout:Clone()
				Variables.admin.Container.TabButtons:ClearAllChildren()
				lol.Parent = Variables.admin.Container.TabButtons
				Variables.admin.AdminPanel.PanelClient.Enabled = true
				Library:Notify({
					Title = Info.AddonTitle,
					Description = 'Debug Admin Panel successfully loaded',
					Time = 3
				})
			end
		})

		Stuff.BypassAnticheat = Groupbox2:AddButton(prefix..'BypassAnticheat', {
			Text = 'Bypass Anticheat',
			DisabledTooltip = 'No admin panel',
			DoubleClick = true,
			Disabled = not Variables.admin,
			Func = function()
				Event:FireServer(
					"Fly",
					{}
				)
				while not required_main_game.noclip do task.wait() end
				required_main_game.noclip = false
				required_main_game.freecam = false
				required_main_game.hideplayers = 0
			end
		})

		local selected_players = nil

		Stuff.Players = Groupbox2:AddDropdown(prefix..'PlayersAdminPanel', {
			SpecialType = 'Player',
			Searchable = true,
			Multi = true,
			Text = 'Players',
			DisabledTooltip = 'No admin panel',
			Default = {},
			Disabled = not Variables.admin,
			Callback = function(value)
				selected_players = value
			end
		})

		Stuff.LagPlayer = Groupbox2:AddButton(prefix..'LagPlayer', {
			Text = 'Lag',
			DisabledTooltip = 'No admin panel',
			Tooltip = 'Lags player',
			DoubleClick = true,
			Disabled = not Variables.admin,
			Func = function()
				local PlayersNames = {}

				for player, _ in selected_players do
					PlayersNames[player.Name] = player.Name
				end

				for _ = 1,100 do
					Event:FireServer("GlitchPlayer", {
						Players = PlayersNames
					})
				end
			end
		})

		Stuff.LagAll = Groupbox2:AddButton(prefix..'LagAll', {
			Text = 'Lag All',
			DisabledTooltip = 'No admin panel',
			Tooltip = 'Lags all players (except you)',
			DoubleClick = true,
			Disabled = not Variables.admin,
			Func = function()
				local _Players = Services.Players:GetPlayers()
				local PlayersNames = {}

				for _, player in _Players do
					if player ~= LocalPlayer then
						PlayersNames[player.Name] = player.Name
					end
				end

				for _ = 1,100 do
					Event:FireServer("GlitchPlayer", {
						Players = PlayersNames
					})
				end
			end
		})
	end

	Groupbox2:AddDivider({
		Text = "TROLL",
		MarginTop = 2,
		MarginBottom = -2
	})

	Toggles.Stun = Groupbox2:AddToggle(prefix..'Stun', {
		Text = 'Stun',
		Enabled = false,

		Callback = function(value, force)
			if force then return end
			if value then
				Character:SetAttribute('Stunned', true)
			else
				Character:SetAttribute('Stunned', false)
			end
		end
	})

	Toggles.ThinkingAnimation = Groupbox2:AddToggle(prefix..'ThinkingAnimation', {
		Text = 'Thinking Animation',
		Enabled = false,

		Callback = function(value)
			if value then
				local animation = Instance.new('Animation')
				animation.AnimationId = 'rbxassetid://' .. thinkanims[math.random(1, #thinkanims)]
				Variables.animtrack = Character:FindFirstChildOfClass('Humanoid'):LoadAnimation(animation)
				Variables.animtrack.Looped = true
				Variables.animtrack:Play()
			else
				if Variables.animtrack then
					Variables.animtrack:Stop()
					Variables.animtrack:Destroy()
				end
			end
		end
	})

	Variables.CollisionOffsetGodmode = Library.Toggles.CollisionOffsetGodmode
	Variables.CollisionOffsetAutomatic = Library.Toggles.CollisionOffsetAutomatic
	Variables.UpsideDownEnabled = false
	Toggles.UpsideDown = Groupbox2:AddToggle(prefix..'UpsideDown', {
		Text = 'Upside Down',
		Tooltip = 'Disables Position Offset to prevent bugs, very buggy',
		Default = false,
		Risky = true,

		Callback = function(value, respawn)
			if value and not Variables.UpsideDownEnabled then
				Variables.UpsideDownEnabled = true
				if Variables.CollisionOffsetGodmode.Value then
					Variables.CollisionOffsetGodmode:SetValue(false)
				end
				if Variables.CollisionOffsetAutomatic.Value then
					Variables.CollisionOffsetAutomatic:SetValue(false)
				end
				if Toggles.CollisionOffsetGodmodeAlt.Value then
					Toggles.CollisionOffsetGodmodeAlt:SetValue(false)
				end
				Variables.CollisionOffsetGodmode:SetDisabled(true)
				Variables.CollisionOffsetAutomatic:SetDisabled(true)
				Toggles.CollisionOffsetGodmodeAlt:SetDisabled(true)
				Character.HumanoidRootPart.Orientation += Vector3.new(0,0,180)
				Connections.UpsideDownConnection = Services.RunService.RenderStepped:Connect(function()
					pcall(function()
						Character.LowerTorso.Root.C0 = CFrame.new(0, 1.206, 0)*CFrame.Angles(0,0,math.rad(180))
					end)
				end)
			elseif not value and Variables.UpsideDownEnabled then
				Variables.UpsideDownEnabled = false
				Variables.CollisionOffsetGodmode:SetDisabled(false)
				Variables.CollisionOffsetAutomatic:SetDisabled(false)
				Toggles.CollisionOffsetGodmodeAlt:SetDisabled(false)
				if Connections.UpsideDownConnection then
					Connections.UpsideDownConnection:Disconnect()
				end
				if not respawn then
					Character.HumanoidRootPart.Orientation += Vector3.new(0,0,180)
					Character.LowerTorso.Root.C0 = CFrame.new(0, -1.206, 0)
				end
			end
		end
	})

	Groupbox2:AddDivider({
		Margin = -6
	})

	local WalkSpoofTable = {
		Methods = {
			ReallyFast = {
				Speed = "Framerate"
			},
			AnnoyingFootsteps = {
				Speed = "Framerate",
				Weight = 0
			},
			InvertedWalk = {
				Speed = "Inverted"
			},
			NoAnimation = {
				Speed = 0,
				Weight = 0
			}
		},
		Method = "NoAnimation"
	}

	local function getMethodValues()
		return WalkSpoofTable.Methods[WalkSpoofTable.Method]
	end

	local selfDontSpoof
	Toggles.WalkAnimSpoof = Groupbox2:AddToggle(prefix..'WalkAnimSpoof', {
		Text = 'Walking Anim Spoof',
		Tooltip = 'Makes your character walking differently',
		Enabled = false,

		Callback = function(value)
			if value then
				Connections.WalkAnimSpoofConnection = Services.RunService.PreAnimation:Connect(function(dt)
					local forward = required_main_game.animations.Forward
					local vals = getMethodValues()
					if selfDontSpoof then
						Services.RunService.PostSimulation:Wait()
					end
					if vals.Speed then
						forward:AdjustSpeed(vals.Speed == "Framerate" and 1/dt or vals.Speed == "Inverted" and -forward.Speed or vals.Speed)
					end
					if vals.Weight then
						forward:AdjustWeight(vals.Weight)
					end
				end)
			else
				if Connections.WalkAnimSpoofConnection then
					Connections.WalkAnimSpoofConnection:Disconnect()
					Connections.WalkAnimSpoofConnection = nil
				end
			end
		end
	})

	Toggles.DontShowSpoofedWalkAnim = Groupbox2:AddToggle(prefix..'DontShowSpoofedWalkAnim', {
		Text = 'Dont Spoof For Yourself',
		Tooltip = "Doesn't change walking animation for yourself",
		Enabled = false,

		Callback = function(value)
			selfDontSpoof = value
		end
	})

	local MethodsIndexWalk = {}
	for index, _ in WalkSpoofTable.Methods do
		table.insert(MethodsIndexWalk, index)
	end

	Groupbox2:AddDropdown(prefix..'WalkMethods', {
		Multi = false,
		Text = 'Methods',
		DisabledTooltip = 'Executor is not supported',
		Disabled = not hookmetamethod,
		Values = MethodsIndexWalk,
		Default = WalkSpoofTable.Method,

		Callback = function(value)
			WalkSpoofTable.Method = value
		end
	})

	Groupbox2:AddDivider({
		Margin = -3
	})

	function disconnectPart(part)
		local part = Connections.PartsConnections[part]
		for index, connection in part or {} do
			connection:Disconnect()
		end
		part = nil
	end

	function handlePart(part)
		if part:IsA("BasePart") then
			Connections.PartsConnections = Connections.PartsConnections or {}
			Connections.PartsConnections[part] = {
				AncestryChanged = part.AncestryChanged:Connect(function()
					if not part.Parent then
						disconnectPart(part)
					end
				end),
				CrazyLoop = Services.RunService.RenderStepped:Connect(function()
					if isnetworkowner(part) and not part.Anchored then
						part.CFrame *= CFrame.Angles(math.rad(math.random(-1800,1800)/100*4),math.rad(math.random(-1800,1800)/100*4),math.rad(math.random(-1800,1800)/100*4))
					end
				end)
			}
		end
	end

	Toggles.CrazyUnanchoredParts = Groupbox2:AddToggle(prefix..'CrazyUnanchoredParts', {
		Text = 'Crazy Unanchored Parts',
		Tooltip = 'Makes unanchored parts go crazy',
		Default = false,

		Callback = function(value)
			if value then
				toggleNetworkOwner(true)
				for _, part in CurrentRooms:GetDescendants() do
					handlePart(part)
				end
				Connections.UnanchoredPartAdded = CurrentRooms.DescendantAdded:Connect(handlePart)
			else
				toggleNetworkOwner(false)
				if Connections.UnanchoredPartAdded then
					Connections.UnanchoredPartAdded:Disconnect()
					Connections.UnanchoredPartAdded = nil
				end
				for part, _ in Connections.PartsConnections or {} do
					disconnectPart(part)
				end
				Connections.PartsConnections = nil
			end
		end
	})

	grumblesOffset = Vector3.new(0,10000,0)
	Toggles.InvisibleGrumbles = Groupbox2:AddToggle(prefix..'InvisibleGrumbles', {
		Text = 'Invisible Grumbles',
		Default = false,

		Callback = function(value)
			if value then
				local nest = CurrentRooms:FindFirstChild('_NestHandler', true)
				local grumbles = nest and nest:FindFirstChild('Grumbles')
				if grumbles then
					toggleNetworkOwner(true)
					Connections.LoopInvisGrumbles = Services.RunService.Heartbeat:Connect(function()
						for _, grumble in grumbles:GetChildren() do
							task.spawn(function()
								local rig = grumble:FindFirstChild("GrumbleRig")
								local root = rig and rig:FindFirstChild("Root")
								if root then
									root.CFrame += grumblesOffset
									Services.RunService.RenderStepped:Wait()
									root.CFrame -= grumblesOffset
								end
							end)
						end
					end)
					Library:Notify({
						Title = Info.AddonTitle,
						Description = "Grumbles won't appear for everyone now! (only you can see them)",
						Time = 4
					})
				else
					Library:Notify({
						Title = Info.AddonTitle.." [Error]",
						Description = 'Grumbles not found',
						Time = 2
					})
					Toggles.InvisibleGrumbles:SetValue(false)
				end
			else
				toggleNetworkOwner(false)
				if Connections.LoopInvisGrumbles then
					Connections.LoopInvisGrumbles:Disconnect()
					Connections.LoopInvisGrumbles = nil
				end
			end
		end
	})

	Toggles.LoopTriggerFigure = Groupbox2:AddToggle(prefix..'LoopTriggerFigure', {
		Text = 'Loop Trigger Figure',
		Tooltip = 'Fakes footsteps to trigger figure',
		Default = false,

		Callback = function()
			while Toggles.LoopTriggerFigure.Value do
				Footstep:FireServer()
				task.wait()
			end
		end
	})

	KeyPickers.TriggerFigureKey = Toggles.LoopTriggerFigure:AddKeyPicker(prefix.."TriggerFigureKey", {
		Text = 'Loop Trigger Figure',
		Default = "Z",
		Mode = Library.IsMobile and "Toggle" or "Hold",
		SyncToggleState = true
	})

	local playerToKill
	Groupbox2:AddDropdown(prefix..'PlayerToKill', {
		SpecialType = 'Player',
		Searchable = true,
		Multi = false,
		Text = 'Player',
		Default = {},
		Callback = function(value)
			playerToKill = value
		end
	})

	local killPlayerWF; killPlayerWF = Groupbox2:AddButton(prefix..'KillPlayerWithFigure', {
		Text = 'Kill Player',
		DisabledTooltip = 'Please wait...',
		Tooltip = 'Requires Figure to be in the same room with selected player',
		DoubleClick = true,
		Func = function()
			if not (Character and Character:FindFirstChild("HumanoidRootPart")) then
				Library:Notify({
					Title = Info.AddonTitle.." [Error]",
					Description = 'Root part of local player is not found',
					Time = 3
				})
				return
			end
			if playerToKill then
				if playerToKill == LocalPlayer then
					Library:Notify({
						Title = Info.AddonTitle.." [Error]",
						Description = "bro u cant kill urself with figure",
						Time = 3
					})
					return
				end
				if playerToKill:GetAttribute("Alive") then
					local Victim = playerToKill.Character
					local VRoot = Victim and Victim:FindFirstChild("HumanoidRootPart")
					if VRoot then
						local figure = workspace:FindFirstChild("FigureRig", true)
						if not figure then
							Library:Notify({
								Title = Info.AddonTitle.." [Error]",
								Description = 'Figure not found',
								Time = 2
							})
							return
						end
						local room = inWhatRoom(figure)
						if room ~= playerToKill:GetAttribute("CurrentRoom") then
							Library:Notify({
								Title = Info.AddonTitle.." [Error]",
								Description = 'Figure is not in the same room with selected player',
								Time = 4
							})
							return
						end
						killPlayerWF:SetDisabled(true)
						local wasEnabled = {Toggles.CollisionOffsetGodmodeAlt.Value, Toggles.InfiniteCrucifixAlt.Value}
						if wasEnabled[1] then
							Toggles.CollisionOffsetGodmodeAlt:SetValue(false)
						end
						if wasEnabled[2] then
							Toggles.InfiniteCrucifixAlt:SetValue(false)
						end
						Toggles.CollisionOffsetGodmodeAlt:SetDisabled(true)
						Toggles.InfiniteCrucifixAlt:SetDisabled(true)
						Crouch:FireServer(nil,true)
						TPPath:ComputeAsync(Character.HumanoidRootPart.Position, VRoot.Position)
						local val = Toggles.AntiTeleport.Value
						if val then
							pcall(Toggles.AntiTeleport.Callback, false)
						end
						if #TPPath:GetWaypoints() > 0 then
							for _, point in TPPath:GetWaypoints() do
								Crouch:FireServer(nil,true)
								Character:PivotTo(CFrame.new(point.Position)+Vector3.new(0,12,0))
								task.wait()
							end
						end
						local OldCFrame = Character.HumanoidRootPart.CFrame
						local Weld = WeldTo(VRoot, CFrame.new(0,9,0))
						local lastfire = -1/0
						local started = os.clock()
						while room == playerToKill:GetAttribute("CurrentRoom") and playerToKill:GetAttribute("Alive") and Weld.Destroy and started > os.clock()-30 do
							Crouch:FireServer(nil,true)
							if lastfire < os.clock()-.5 then
								lastfire = os.clock()
								Footstep:FireServer()
							end
							task.wait()
						end
						if Weld.Destroy then Weld:Destroy() end
						settings().Physics.AllowSleep = Weld.OldAllowSleep
						task.wait()
						TPPath:ComputeAsync(VRoot.Position, OldCFrame.Position)
						if #TPPath:GetWaypoints() > 0 then
							for _, point in TPPath:GetWaypoints() do
								Crouch:FireServer(nil,true)
								Character:PivotTo(CFrame.new(point.Position)+Vector3.new(0,12,0))
								task.wait()
							end
							Character:PivotTo(OldCFrame)
						else
							Character:PivotTo(OldCFrame)
						end
						if val then
							pcall(Toggles.AntiTeleport.Callback, true)
						end
						Crouch:FireServer()
						if playerToKill:GetAttribute("Alive") then
							Library:Notify({
								Title = Info.AddonTitle.." [Error]",
								Description = 'Failed to kill selected player',
								Time = 3
							})
						else
							Library:Notify({
								Title = Info.AddonTitle,
								Description = 'Successfully killed selected player',
								Time = 3
							})
						end
					else
						Library:Notify({
							Title = Info.AddonTitle.." [Error]",
							Description = 'Root part of selected player not found',
							Time = 3
						})
					end 
				else
					Library:Notify({
						Title = Info.AddonTitle.." [Error]",
						Description = 'Selected player is already dead',
						Time = 3
					})
				end
			else
				Library:Notify({
					Title = Info.AddonTitle.." [Error]",
					Description = 'No selected player',
					Time = 2
				})
			end
			killPlayerWF:SetDisabled(false)
			if wasEnabled[1] then
				Toggles.CollisionOffsetGodmodeAlt:SetValue(true)
			end
			if wasEnabled[2] then
				Toggles.InfiniteCrucifixAlt:SetValue(true)
			end
			Toggles.CollisionOffsetGodmodeAlt:SetDisabled(false)
			Toggles.InfiniteCrucifixAlt:SetDisabled(false)
		end
	})

	Groupbox2:AddDivider({
		Margin = -3
	})

	Variables.MethodsIndex = {}
	for index, _ in Variables.motorReplicaAbuse.methods do
		table.insert(Variables.MethodsIndex, index)
	end

	Groupbox2:AddDropdown(prefix..'MotorMethods', {
		Multi = false,
		Text = 'Methods',
		DisabledTooltip = 'Executor is not supported',
		Disabled = not hookmetamethod,
		Values = Variables.MethodsIndex,
		Default = Variables.motorReplicaAbuse.method,

		Callback = function(value)
			Variables.motorReplicaAbuse.method = value
			if not Variables.motorReplicaAbuse.enabled then return end
			local method = Variables.motorReplicaAbuse.methods[value]
			if Connections.CurrentLVYAbuseMethodConnection then
				Connections.CurrentLVYAbuseMethodConnection:Disconnect()
				Connections.CurrentLVYAbuseMethodConnection = nil
			end
			if typeof(method) == "table" and method.methodType == "Number" then
				MotorReplication:FireServer(0)
			elseif typeof(method) == "function" then
				if Connections.CurrentLVYAbuseMethodConnection then
					Connections.CurrentLVYAbuseMethodConnection:Disconnect()
					Connections.CurrentLVYAbuseMethodConnection = nil
				end
				Connections.CurrentLVYAbuseMethodConnection = method()
			end
		end
	})

	Variables.MotorSpeed = Groupbox2:AddSlider("LadderSpeed", {
		Text = "Speed",
		Default = 1,
		Min = 0.5,
		Max = 2,
		Rounding = 2,
		Compact = true
	})

	Toggles.MotorAbuse = Groupbox2:AddToggle(prefix..'MotorAbuse', {
		Text = 'LVY Abuse',
		Tooltip = 'Does some funny stuff with Motor Replication event (Everyone will see this)',
		Default = Variables.motorReplicaAbuse.enabled,
		DisabledTooltip = 'Executor is not supported',
		Disabled = not hookmetamethod,

		Callback = function(value)
			Variables.motorReplicaAbuse.enabled = value
			local method = Variables.motorReplicaAbuse.methods[Variables.motorReplicaAbuse.method]
			if value then
				if typeof(method) == "table" and method.methodType == "Number" then
					MotorReplication:FireServer(0)
				elseif typeof(method) == "function" then
					if Connections.CurrentLVYAbuseMethodConnection then
						Connections.CurrentLVYAbuseMethodConnection:Disconnect()
						Connections.CurrentLVYAbuseMethodConnection = nil
					end
					Connections.CurrentLVYAbuseMethodConnection = method()
				end
			else
				if Connections.CurrentLVYAbuseMethodConnection then
					Connections.CurrentLVYAbuseMethodConnection:Disconnect()
					Connections.CurrentLVYAbuseMethodConnection = nil
				end
				MotorReplication:FireServer(0)
			end
		end
	})

	Groupbox:AddDivider({
		Text = "ITEMS",
		MarginTop = 2,
		MarginBottom = -2
	})

	Variables.itemsOffset = Vector3.zero
	Variables.selectedPlayerItem = nil
	Variables.old = {}

	function toggleNetworkOwner(bool)
		if not(gethiddenproperty and sethiddenproperty) then return end
		if (Toggles.InvisibleGrumbles.Value or Toggles.LoopSteal.Value or Toggles.DisableMandrakeFEAlt.Value or Toggles.OrbitDrops.Value or Toggles.OrbitGlowsticks.Value or Toggles.CrazyUnanchoredParts.Value or Toggles.BringDrawers.Value) and not bool then return end
		if bool and not Connections.network then
			Variables.old.allowSleep = settings().Physics.AllowSleep
			Variables.old.replicaFocus = LocalPlayer.ReplicationFocus
			Variables.old.maxSimRadius = gethiddenproperty(LocalPlayer, 'MaximumSimulationRadius')
			Variables.old.simRadius = gethiddenproperty(LocalPlayer, 'SimulationRadius')
			settings().Physics.AllowSleep = false
			LocalPlayer.ReplicationFocus = workspace
			Connections.network = Services.RunService.Heartbeat:Connect(function()
				sethiddenproperty(LocalPlayer, 'MaximumSimulationRadius', 1/0)
				sethiddenproperty(LocalPlayer, 'SimulationRadius', 1/0)
				if replicatesignal then
					pcall(replicatesignal, LocalPlayer.SimulationRadiusChanged, 1/0)
				end
				for _, Player in Services.Players:GetPlayers() do
					if Player == LocalPlayer then return end
					sethiddenproperty(Player, 'MaxSimulationRadius', 0)
					sethiddenproperty(Player, 'SimulationRadius', 0)
					if replicatesignal then
						pcall(replicatesignal, Player.SimulationRadiusChanged, 0)
					end
				end
			end)
		elseif not bool and Connections.network then
			settings().Physics.AllowSleep = Variables.old.allowSleep
			Connections.network:Disconnect()
			Connections.network = nil
			LocalPlayer.ReplicationFocus = Variables.old.replicaFocus
			sethiddenproperty(LocalPlayer, 'MaximumSimulationRadius', Variables.old.maxSimRadius)
			sethiddenproperty(LocalPlayer, 'SimulationRadius', Variables.old.simRadius)
			if replicatesignal then
				pcall(replicatesignal, LocalPlayer.SimulationRadiusChanged, Variables.old.simRadius)
			end
			Variables.old = {}
		end
	end

	Variables.connectedPrompts = {}

	local function activatePrompt(hrp, drop, prompt)
		if typeof(prompt) == 'Instance' and prompt:IsA('ProximityPrompt') then
			local connection = {changeHrp = function(newhrp)
				hrp = newhrp or hrp
			end}
			function connection:onActivate()
				self = nil
			end
			table.insert(Variables.connectedPrompts, connection)
			task.spawn(function()
				local lastDetectedHrp = os.clock()
				while prompt.Parent and connection and os.clock()-lastDetectedHrp < 3 do
					if hrp.Parent then
						lastDetectedHrp = os.clock()
						drop:PivotTo(hrp.CFrame + itemsOffset)
						fireproximityprompt(prompt)
					end
					for _ = 1,math.clamp(#Variables.connectedPrompts,1,1/0) do -- math.clamp is here to prevent 'while true do end' crash
						task.wait()
					end
				end
				if connection then
					connection:onActivate()
				end
			end)
			return connection
		end
	end

	Groupbox:AddDropdown(prefix..'PlayerToBringItems', {
		SpecialType = 'Player',
		Searchable = true,
		Multi = true,
		Text = 'Player',
		Default = {},
		Callback = function(value)
			Variables.selectedPlayerItem = value
		end
	})

	Groupbox:AddButton(prefix.."BringDrops", {
		Text = 'Bring Drops',
		Tooltip = 'Bring all the dropped items to your current player',
		Func = function()
			local char = Variables.selectedPlayerItem and Variables.selectedPlayerItem.Character or Character
			local human = char and char:FindFirstChild('Humanoid')
			local hrp = human and human.RootPart

			if hrp then
				toggleNetworkOwner(true)
				for _, drop in Drops:GetChildren() do
					if drop:IsA('BasePart') then
						drop.CFrame = hrp.CFrame + Variables.itemsOffset
					elseif drop:IsA('Model') then
						drop:PivotTo(hrp.CFrame + Variables.itemsOffset)
					end
				end
				toggleNetworkOwner(false)
			end
		end
	})

	Groupbox:AddDivider({
		Margin = -6
	})

	Groupbox:AddButton(prefix.."StealDrops", {
		Text = 'Steal Drops',
		Tooltip = 'Steal all the dropped items',
		Func = function()
			local char = Character
			local human = char and char:FindFirstChild('Humanoid')
			local hrp = human and human.RootPart

			if hrp then
				toggleNetworkOwner(true)
				for _, drop in Drops:GetChildren() do
					if drop:IsA('BasePart') then
						activatePrompt(hrp, drop, drop:FindFirstChild('ModulePrompt', true))
					elseif drop:IsA('Model') then
						activatePrompt(hrp, drop, drop:FindFirstChild('ModulePrompt', true))
					end
				end
				toggleNetworkOwner(false)
			end
		end
	})

	Toggles.LoopSteal = Groupbox:AddToggle(prefix..'LoopSteal', {
		Text = 'Loop Steal Drops',
		Tooltip = 'Loop steal all the dropped items (except yours)',
		Default = false,
		Callback = function(bool)
			if not bool then
				if Connections.loop then
					Connections.loop:Disconnect()
					Connections.loop = nil
				end
				if Connections.charchanged then
					Connections.charchanged:Disconnect()
					Connections.charchanged = nil
				end
				if Connections.rootchanged then
					Connections.rootchanged:Disconnect()
					Connections.rootchanged = nil
				end
				for _, connection in Variables.connectedPrompts do
					connection:onActivate()
				end
				toggleNetworkOwner(false)
				return
			end

			local char = Character or LocalPlayer.CharacterAdded:Wait()
			local human = char:WaitForChild('Humanoid', 99)
			local hrp = human.RootPart
			Connections.rootchanged = human:GetPropertyChangedSignal("RootPart"):Connect(function()
				hrp = human.RootPart
				for _, connection in Variables.connectedPrompts do
					connection:changeHrp(hrp)
				end
			end)

			if not Toggles.LoopSteal.Value then return end

			if hrp then
				toggleNetworkOwner(true)
				for _, drop in Drops:GetChildren() do
					if drop:GetAttribute("PlayerName") == LocalPlayer.Name then continue end
					if drop:IsA('BasePart') then
						activatePrompt(hrp, drop, drop:FindFirstChild('ModulePrompt', true))
					elseif drop:IsA('Model') then
						activatePrompt(hrp, drop, drop:FindFirstChild('ModulePrompt', true))
					end
				end
				Connections.loop = Drops.ChildAdded:Connect(function(drop)
					if drop:GetAttribute("PlayerName") == LocalPlayer.Name then return end
					if drop:IsA('BasePart') then
						activatePrompt(hrp, drop, drop:FindFirstChild('ModulePrompt', true))
					elseif drop:IsA('Model') then
						activatePrompt(hrp, drop, drop:FindFirstChild('ModulePrompt', true))
					end
				end)
				Connections.charchanged = LocalPlayer.CharacterAdded:Connect(function(c)
					char = c
					human = c:WaitForChild('Humanoid', 99)
					hrp = human.RootPart or hrp
					if Connections.rootchanged then
						Connections.rootchanged:Disconnect()
					end
					Connections.rootchanged = human:GetPropertyChangedSignal("RootPart"):Connect(function()
						hrp = human.RootPart
						for _, connection in Variables.connectedPrompts do
							connection:changeHrp(hrp)
						end
					end)
					for _, connection in Variables.connectedPrompts do
						connection:changeHrp(hrp)
					end
				end)
			else
				toggle:SetValue(false)
			end
		end
	})

	Groupbox:AddDivider({
		Margin = -6
	})

	local Settings = {}
	local VisualOrbitOffset = Vector3.new(0,-128,0)
	Toggles.OrbitDrops = Groupbox:AddToggle(prefix..'OrbitDrops', {
		Text = 'Orbit Drops',
		Default = false,
		Callback = function(bool)
			if bool then
				toggleNetworkOwner(true)
				local val = 0
				Connections.OrbitDropsConnection = Services.RunService.Heartbeat:Connect(function(dt)
					val = (val + dt * 90 * Settings.Speed.Value) % 360
					local Root = Character and Character:FindFirstChild("HumanoidRootPart")
					if Root and Character:GetAttribute("Alive") then
						local drops = Drops:QueryDescendants(`> Model[$PlayerName = {LocalPlayer.Name}]`)
						for num, drop in drops do
							local main = drop:FindFirstChild("Main")
							if main then
								main.AssemblyLinearVelocity = Vector3.zero
								main.CanQuery = not Toggles.NoPrompt.Value
							end
							drop:PivotTo((CFrame.Angles(0, math.rad(val - 360 / #drops * num), 0) + Root.Position) * CFrame.new(0, 0, Settings.Offset.Value) + (Toggles.AntiSteal.Value and VisualOrbitOffset or Vector3.zero))
							local prompt = drop:FindFirstChild("ModulePrompt")
							if prompt then
								prompt.Enabled = not Toggles.NoPrompt.Value
							end
							local itemDropPickup = drop:FindFirstChild("ItemDropPickup")
							if itemDropPickup then
								itemDropPickup.CanCollide = not Toggles.NoPrompt.Value
								itemDropPickup.CanQuery = not Toggles.NoPrompt.Value
							end
						end
						if Toggles.AntiSteal.Value then
							Services.RunService.RenderStepped:Wait()
							for num, drop in drops do
								drop:PivotTo(drop:GetPivot() - VisualOrbitOffset)
							end
						end
					end
				end)
			else
				toggleNetworkOwner(false)
				if Connections.OrbitDropsConnection then
					if Toggles.AntiSteal.Value then
						pcall(Toggles.AntiSteal.Callback, false)
						Services.RunService.RenderStepped:Wait()
					end
					Connections.OrbitDropsConnection:Disconnect()
					Connections.OrbitDropsConnection = nil
					if Toggles.NoPrompt.Value then
						local drops = Drops:QueryDescendants(`> Model[$PlayerName = {LocalPlayer.Name}]`)
						for num, drop in drops do
							local prompt = drop:FindFirstChild("ModulePrompt")
							if prompt then
								prompt.Enabled = true
							end
							local main = drop:FindFirstChild("Main")
							if main then
								main.CanQuery = true
							end
							local itemDropPickup = drop:FindFirstChild("ItemDropPickup")
							if itemDropPickup then
								itemDropPickup.CanCollide = true
								itemDropPickup.CanQuery = true
							end
						end
					end
				end
			end
		end
	})

	Toggles.OrbitGlowsticks = Groupbox:AddToggle(prefix..'OrbitGlowsticks', {
		Text = 'Orbit Glowsticks',
		Default = false,
		Callback = function(bool)
			if bool then
				toggleNetworkOwner(true)
				local val = 0
				Connections.OrbitGlowsticksConnection = Services.RunService.Heartbeat:Connect(function(dt)
					val = (val + dt * 90 * Settings.Speed.Value) % 360
					local Root = Character and Character:FindFirstChild("HumanoidRootPart")
					if Root and Character:GetAttribute("Alive") then
						local sticks = workspace:QueryDescendants(`> #GlowstickLive[$Owner = {LocalPlayer.Name}]`)
						for num, stick in sticks do
							stick.CFrame = (CFrame.Angles(0, math.rad(val - 360 / #sticks * num), 0) + Root.Position) * CFrame.new(0, 0, Settings.Offset.Value)
							stick.AssemblyLinearVelocity = Vector3.zero
						end
					end
				end)
			else
				toggleNetworkOwner(false)
				if Connections.OrbitGlowsticksConnection then
					Connections.OrbitGlowsticksConnection:Disconnect()
					Connections.OrbitGlowsticksConnection = nil
				end
			end
		end
	})

	Settings.Speed = Groupbox:AddSlider(prefix.."Speed", {
		Text = "Speed",
		Default = 1,
		Min = 0,
		Max = 4,
		Rounding = 1,
	})

	Settings.Offset = Groupbox:AddSlider(prefix.."Offset", {
		Text = "Offset",
		Default = 4,
		Min = 2,
		Max = 8,
		Rounding = 1,
	})

	Toggles.AntiSteal = Groupbox:AddToggle(prefix..'AntiSteal', {
		Text = 'Anti Steal',
		Tooltip = "Doesn't allow players to steal items while Orbit Drops is on",
		Default = false
	})

	Toggles.NoPrompt = Groupbox:AddToggle(prefix..'NoPrompt', {
		Text = 'No Prompt',
		Tooltip = 'Hides the prompt while Orbit Drops is on',
		Default = false
	})

	Groupbox2:AddDivider({
		Text = "MISC",
		MarginTop = 2,
		MarginBottom = -2
	})

	local sound = '7107161936'
	local color = Color3.new(1,1,1)
	local captionEnabled = false

	Toggles.DeluluCaption = Groupbox2:AddToggle(prefix..'DeluluCaption', {
		Text = 'Delulu Caption',
		Tooltip = 'Caption from delusional office',
		DisabledTooltip = 'Please wait...',
		Disabled = not spawncaption,
		Default = false,

		Callback = function(value)
			if value then
				captionEnabled = true
				main_game.Reminder.Enabled = false
				Connections.caption = RemotesFolder.Caption.OnClientEvent:Connect(function(text)
					spawncaption(script1.Parent:WaitForChild('MainTextFrameSample'), script1.Parent, text, `rbxassetid://{sound}`, color)
				end)
				Connections.disableogcaption = Services.RunService.RenderStepped:Connect(function()
					pcall(function()
						main_game.Reminder.Enabled = false
					end)
				end)
			else
				if not captionEnabled then return end
				captionEnabled = false
				Connections.caption:Disconnect()
				Connections.disableogcaption:Disconnect()
				main_game.Reminder.Enabled = true
			end
		end
	})

	task.spawn(function()
		while not spawncaption and loaded do
			task.wait()
		end
		if loaded then
			Toggles.DeluluCaption:SetDisabled(false)
		end
	end)

	local DeluluSettings = Groupbox2:AddDependencyBox(prefix.."DeluluSettings")

	DeluluSettings:AddInput(prefix..'DeluluSound', {
		Text = 'Caption Sound',
		Numeric = true,
		Finished = true,
		ClearTextOnFocus = true,
		Placeholder = sound,
		Default = sound,

		Callback = function(newsound)
			sound = newsound
		end
	})

	DeluluSettings:AddLabel('Caption Color'):AddColorPicker(prefix..'DeluluColor', {
		Title = 'Caption Color',
		Default = color,

		Callback = function(newcolor)
			color = newcolor
		end
	})

	DeluluSettings:SetupDependencies({
		{ Toggles.DeluluCaption, true }
	})

	Groupbox2:AddDivider({
		Margin = -6
	})

	local light = "Blue"

	Groupbox2:AddDropdown(prefix..'Lights', {
		Multi = false,
		Text = 'Lights',
		DisabledTooltip = 'Executor is not supported',
		Disabled = not firesignal,
		Values = {
			"Blue",
			"Yellow",
			"Glitch",
			"Rush"
		},
		Default = light,

		Callback = function(value)
			light = value
		end
	})

	local EvilTexts = {
		Blue = {
			Rush = {
				NoPosOffset = {
					"You died to Rush.",
					"Why can't you just hide in the closet.",
					"Are you stupid?"
				},
				PosOffset = {
					"Okay that is absolutely TERRIBLE...",
					"You died to a Rush with a FRICKING POSITION OFFSET.",
					"ARE YOU A ####### OR SOMETHING!?",
					"...",
					"You should probably get better at this game, NOOB."
				}
			},
			Blitz = {
				NoPosOffset = {
					"You died to Blitz.",
					"Why can't you just hide in the closet.",
					"Are you stupid?"
				},
				PosOffset = {
					"Okay that is TERRIBLE...",
					"You died to a Blitz with a POSITION OFFSET.",
					"HOW DID YOU EVEN MANAGED TO DIE!?!?",
					"You should probably get better at this game, NOOB."
				}
			},
			Ambush = {
				NoPosOffset = {
					"And you died to Ambush.",
					"Well, not surprised."
				},
				PosOffset = {
					"You have a Position Offset on...",
					"AND YOU STILL DIED TO AMBUSH!!!",
					"You can't even play this game with cheats!"
				}
			},
			ClientEntity = {
				"...",
				"Listen to me, skid.",
				"You can just disable this entity.",
				"But because you didn't do it,",
				"You probably can't have more than 7 IQ."
			},
			Other = {
				"You died to %s with cheats.",
				"Pfft, get better LOL."
			}
		},
		Yellow = {
			Rush = {
				NoPosOffset = {
					"Okay who killed you this time.",
					"...",
					"Bro, you was able to enter the ####### closet to survive,",
					"But because you are stupid you didn't do it."
				},
				PosOffset = {
					"Okay who killed you this time.",
					"...",
					"Well, you are terrible at this game,",
					"Can you just ####### leave please?"
				}
			},
			Blitz = {
				NoPosOffset = {
					"Who killed you this time.",
					"Ehh.. this guy.",
					"You was able just to hide in the closet to survive him bro,",
					"How many times i should repeat this."
				},
				PosOffset = {
					"Who killed you this time.",
					"Oh.",
					"Lmfao i think you have skill issue,",
					"Just get better bro."
				}
			},
			Ambush = {
				NoPosOffset = {
					"And you died to Ambush.",
					"Well, not surprised."
				},
				PosOffset = {
					"You have a Position Offset on...",
					"AND YOU STILL DIED TO AMBUSH!!!",
					"You can't even play this game with cheats!"
				}
			},
			ClientEntity = {
				"Press Right Shift,",
				"Go to Exploits,",
				"And disable the ####### entity, you #######."
			},
			Other = {
				"#### off bro Im not curious about who caused your death."
			}
		},
		Glitch = {
			Rush = {
				NoPosOffset = {
					"PRESS ALT+F4 TWICE TO REMOVE RUSH",
					"SO YOU DON'T HAVE TO HIDE"
				},
				PosOffset = {
					">",
					"SKID SKID SKID SAHUR"
				}
			},
			Blitz = {
				NoPosOffset = {
					"PRESS ALT+F4 TWICE TO REMOVE BLITZ",
					"SO YOU DON'T HAVE TO HIDE"
				},
				PosOffset = {
					">",
					"HEY, YOU [_] STUPID!"
				}
			},
			Ambush = {
				NoPosOffset = {
					"PRESS ALT+F4 TWICE TO REMOVE AMBUSH",
					"SO YOU DON'T HAVE TO HIDE"
				},
				PosOffset = {
					">",
					"EXECUTE 'setrawmetatable(game, {})'"
				}
			},
			ClientEntity = {
				">",
				"BRO DISABLE HIM :SOB:"
			},
			Other = {
				"WELL WELL WELL",
				">",
				unpack(table.create(100, "A")) -- this is gonna be fun
			}
		},
		Rush = {
			Rush = {
				NoPosOffset = table.create(math.random(1,5), string.rep("RUSH ", math.random(5, 10))),
				PosOffset = table.create(math.random(1,5), string.rep("RUSH ", math.random(5, 10)))
			},
			Blitz = {
				NoPosOffset = table.create(math.random(1,5), string.rep("RUSH ", math.random(5, 10))),
				PosOffset = table.create(math.random(1,5), string.rep("RUSH ", math.random(5, 10)))
			},
			Ambush = {
				NoPosOffset = table.create(math.random(1,5), string.rep("RUSH ", math.random(5, 10))),
				PosOffset = table.create(math.random(1,5), string.rep("RUSH ", math.random(5, 10)))
			},
			ClientEntity = table.create(math.random(1,5), string.rep("RUSH ", math.random(5, 10))),
			Other = table.create(math.random(1,5), string.rep("RUSH ", math.random(5, 10)))
		}
	}

	local Rushers = {
		"Rush",
		"Blitz",
		"Ambush"
	}

	local ClientEntities = {
		"Screech",
		"A-90",
		"Halt",
		"Snare",
		"Drones",
		"Drone",
		"Scribbles",
		"Alma",
		"Ransom"
	}

	local function pickEvilDialogue(light)
		local lightTexts = EvilTexts[light]
		local deathCause = Character:GetAttribute("DeathCause")
		if table.find(Rushers, deathCause) then
			local texts = lightTexts[deathCause]
			return Toggles.CollisionOffsetGodmodeAlt.Value and texts.PosOffset or texts.NoPosOffset
		elseif table.find(ClientEntities, deathCause) then
			return lightTexts.ClientEntity
		else
			return lightTexts.Other
		end
	end

	local lod = false
	local nld = false
	local edc = false
	local deathHintConnection = firesignal and DeathHint.OnClientEvent:Connect(function(texts, lightName, exploited)
		if not exploited and (lod or nld) then
			lightName = lod and light or lightName
			texts = nld and {} or edc and pickEvilDialogue(lightName) or texts
			for _ = 1,30 do -- so it would work 100%
				firesignal(DeathHint.OnClientEvent, texts, lightName, true)
				task.wait()
			end
		end
	end)

	Toggles.LightOnDeath = Groupbox2:AddToggle(prefix..'LightOnDeath', {
		Text = 'Light On Death',
		Tooltip = "Replace default light on current floor with other ones (text wouldn't change)",
		DisabledTooltip = 'Executor is not supported',
		Disabled = not deathHintConnection,
		Default = false,

		Callback = function(value)
			lod = value
		end
	})

	Toggles.NoLightDialog = Groupbox2:AddToggle(prefix..'NoLightDialog', {
		Text = 'No Light Dialog',
		Tooltip = "Remove dialog after you died",
		DisabledTooltip = 'Executor is not supported',
		Disabled = not deathHintConnection,
		Default = false,

		Callback = function(value)
			if Toggles.EvilLights.Value and value then
				Toggles.EvilLights:SetValue(false)
			end
			nld = value
		end
	})

	Toggles.EvilLights = Groupbox2:AddToggle(prefix..'EvilLights', {
		Text = 'Evil Lights',
		Tooltip = "Lights instead of helping you saying something else (why i made this)",
		DisabledTooltip = 'Executor is not supported',
		Disabled = not deathHintConnection,
		Default = false,

		Callback = function(value)
			if Toggles.NoLightDialog.Value and value then
				Toggles.NoLightDialog:SetValue(false)
			end
			edc = value
		end
	})

	Groupbox:AddDivider({
		Text = "ANTI ENTITIES",
		MarginTop = 2,
		MarginBottom = -2
	})

	Toggles.CollisionOffsetGodmodeAlt = NoAltFeatures() or Groupbox:AddToggle(prefix..'CollisionOffsetGodmodeAlt', {
		Text = 'Position Offset Alt',
		Tooltip = "Alternative method of Position Offset (source from Abysall, modified by tplaygd)",
		Default = false,

		Callback = function(value)
			if value then
				if Toggles.AntiGroundskeeper.Value then
					Toggles.AntiGroundskeeper:SetValue(false)
				end
				if Toggles.AntiFigure.Value then
					Toggles.AntiFigure:SetValue(false)
				end
				DoStuffWithAntiTp()
				Variables.cogAlt = true
				Crouch:FireServer(true)
				Connections.POA = Services.RunService.Heartbeat:Connect(function()
					if not Variables.hook then
						Crouch:FireServer(true)
					end
					Character.HumanoidRootPart.CFrame *= CFrame.new(0, -2.146, 0)
					Character.CollisionPart.Weld.C1 = CFrame.new(0, 2.146, 0)
					Services.RunService.RenderStepped:Wait()
					Character.HumanoidRootPart.CFrame *= CFrame.new(0, 2.146, 0)
					Character.CollisionPart.Weld.C1 = CFrame.new(0, 0, 0)
					Camera.CFrame += Vector3.new(0, 2.146, 0)
				end)
			elseif Variables.cogAlt then
				Variables.cogAlt = false
				if Connections.POA then
					Connections.POA:Disconnect()
				end
				Character.HumanoidRootPart.CFrame *= CFrame.new(0, 2.146, 0)
				Character.CollisionPart.Weld.C1 = CFrame.new(0, 0, 0)
			end
		end
	})

	KeyPickers.CollisionOffsetGodmodeAltKey = Toggles.CollisionOffsetGodmodeAlt.Callback and Toggles.CollisionOffsetGodmodeAlt:AddKeyPicker(prefix.."CollisionOffsetGodmodeAltKey", {
		Text = "Position Offset Alt",
		Default = "U",
		Mode = "Toggle",
		SyncToggleState = true
	})

	local RaycastParams = RaycastParams.new()
	RaycastParams.FilterType = Enum.RaycastFilterType.Include
	RaycastParams.RespectCanCollide = true

	local function visualizeRaycast(startpos, endpos, success)
		if not ADDON_CONFIG.Debug then return end
		local part = Instance.new("Part", workspace)
		local ok = endpos-startpos
		part.Size = Vector3.new(.1,.1,ok.Magnitude)
		part.CFrame = CFrame.lookAt(startpos, endpos)+ok.Unit*(ok.Magnitude/2)
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Anchored = true
		part.Color = success and Color3.new(0,1) or Color3.new(1)
		Services.Debris:AddItem(part, 5)
	end

	Variables.ping = 0
	task.spawn(function()
		while task.wait(1/15) and loaded do
			task.spawn(function()
				local start = os.clock()
				RequestLocalAsset:InvokeServer({{}})
				Variables.ping = os.clock()-start
			end)
		end
	end)

	local Dupes = {}
	local function handleDupe(sideroomDupe)
		local hidden = sideroomDupe:WaitForChild("DoorFake", 1/0):WaitForChild("Hidden", 1/0)
		Connections[sideroomDupe] = hidden.Touched:Connect(function(hit)
			local collision = Character and Character:FindFirstChild("Collision")
			local tool = GetEquippedTool(LocalPlayer)
			if hit == collision and tool and tool.Name == "Crucifix" then
				table.remove(Dupes, table.find(Dupes, sideroomDupe))
				Connections[sideroomDupe]:Disconnect()
				Connections[sideroomDupe] = nil
				task.wait()
				DropItem:FireServer(tool)
				local crucifix
				local con; con = Drops.ChildAdded:Connect(function(child)
					if child.Name == "Crucifix" and child:GetAttribute("PlayerName") == LocalPlayer.Name then
						crucifix = child
						con:Disconnect()
					end
				end)
				while not crucifix do
					task.wait()
				end
				task.spawn(function()
					local start = os.clock()
					local prompt = crucifix:WaitForChild("ModulePrompt", 3)
					if prompt then
						crucifix:PivotTo(Character:GetPivot())
						if start <= os.clock()-.5 then
							fireproximityprompt(prompt)
						end
						while crucifix.Parent do
							task.wait()
							crucifix:PivotTo(Character:GetPivot())
							if start <= os.clock()-.5 then
								fireproximityprompt(prompt)
							end
						end
					end
				end)
			end
		end)
		table.insert(Dupes, sideroomDupe)
	end

	Variables.Range = {
		RushMoving = 50,
		AmbushMoving = 60,
		["A60"] = 60,
	}

	Variables.AntiDupe = Library.Toggles.AntiDupe

	Toggles.InfiniteCrucifixAlt = NoAltFeatures() or Groupbox:AddToggle(prefix..'InfiniteCrucifixAlt', {
		Text = 'Infinite Crucifix',
		Risky = true,
		Tooltip = 'Should have more chance to dupe crucifix (WORKS ONLY ON RUSH, AMBUSH, A-60, DUPE)',
		Default = false,

		Callback = function(value)
			if value then
				if Variables.AntiDupe.Value then
					Variables.AntiDupe:SetValue(false)
				end
				Variables.AntiDupe:SetDisabled(true)
				Connections.InfiniteCrucifixConnection = workspace.ChildAdded:Connect(function(child)
					local n = child.Name
					if n=="RushMoving" or n=="AmbushMoving" or n=="A60" then
						local main = child:FindFirstChildWhichIsA("BasePart")
						if main then
							local speedTable = {}
							local speed = 0
							local dir = Vector3.zero
							local crucifixed = false
							task.spawn(function()
								local startpos = main.Position
								while startpos == main.Position do
									task.wait()
								end
								while not crucifixed do
									local pos = main.Position
									local dt = task.wait(1/60)
									local yea = main.Position-pos
									table.insert(speedTable, yea.Magnitude/dt)
									dir = yea.Unit
									if #speedTable > 60 then
										table.remove(speedTable, 1)
									end
									speed = 0
									for _, speed1 in speedTable do
										speed += speed1
									end
									speed /= #speedTable
								end
							end)
							while child.Parent do
								local cpart = Character and Character:FindFirstChild("CollisionPart")
								local tool = GetEquippedTool(LocalPlayer)
								RaycastParams.FilterDescendantsInstances = {CurrentRooms, cpart}
								local predictedpos = main.Position+(dir*Variables.ping)
								local yea = Variables.Range[n]
								local raycast = cpart and workspace:Raycast(predictedpos, (cpart.Position-predictedpos).Unit*yea, RaycastParams)
								local success = raycast and raycast.Instance == cpart
								--logprint(yea)
								logprint(raycast, raycast and raycast.Position, raycast and raycast.Instance)
								visualizeRaycast(predictedpos, raycast and raycast.Position or predictedpos+(cpart.Position-predictedpos).Unit*yea, success)
								if success and tool and tool.Name == "Crucifix" then
									log("DROP CRUCIFIX")
									DropItem:FireServer(tool)
									local crucifix
									local con1; con1 = child.AncestryChanged:Connect(function()
										if not child.Parent then
											crucifixed = true
											con1:Disconnect()
										end
									end)
									local con2; con2 = Drops.ChildAdded:Connect(function(child)
										if child.Name == "Crucifix" and child:GetAttribute("PlayerName") == LocalPlayer.Name then
											crucifix = child
											con2:Disconnect()
										end
									end)
									while not crucifix do
										task.wait()
									end
									task.spawn(function()
										local start = os.clock()
										local prompt = crucifix:WaitForChild("ModulePrompt", 3)
										if prompt then
											crucifix:PivotTo(Character:GetPivot())
											if not child.Parent or start <= os.clock()-1.5 then
												fireproximityprompt(prompt)
											end
											while crucifix.Parent do
												task.wait()
												crucifix:PivotTo(Character:GetPivot())
												if not child.Parent or start <= os.clock()-1.5 then
													fireproximityprompt(prompt)
												end
											end
										end
									end)
									break
								end
								Services.RunService.Heartbeat:Wait()
							end
						end
					end
				end)
				Connections.OnDupeAnimation = Character:GetAttributeChangedSignal("Animating"):Connect(function()
					Character:SetAttribute("Animating", false)
				end)
				for _, dupe in CurrentRooms:QueryDescendants("Model >> #SideroomDupe") do
					handleDupe(dupe)
				end
				Connections.OnDupeSpawned = CurrentRooms.DescendantAdded:Connect(function(descendant)
					if descendant.Name == "SideroomDupe" then
						handleDupe(descendant)
					end
				end)
				Connections.OnDupeRemoved = CurrentRooms.DescendantRemoving:Connect(function(descendant)
					if descendant.Name == "SideroomDupe" then
						Connections[descendant]:Disconnect()
						Connections[descendant] = nil
						table.remove(Dupes, table.find(Dupes, descendant))
					end
				end)
			else
				Variables.AntiDupe:SetDisabled(false)
				if Connections.InfiniteCrucifixConnection then
					Connections.InfiniteCrucifixConnection:Disconnect()
					Connections.InfiniteCrucifixConnection = nil
				end
				if Connections.OnDupeAnimation then
					Connections.OnDupeAnimation:Disconnect()
					Connections.OnDupeAnimation = nil
				end
				if Connections.OnDupeSpawned then
					Connections.OnDupeSpawned:Disconnect()
					Connections.OnDupeSpawned = nil
				end
				for _, dupe in Dupes do
					Connections[dupe]:Disconnect()
					Connections[dupe] = nil
				end
				Dupes = {}
			end
		end
	})

	Variables.MandrakesPos = {}

	StuffToRemoveLater.voidpos = Instance.new("BodyPosition")
	StuffToRemoveLater.voidpos.MaxForce = Vector3.new(1/0, 1/0, 1/0)
	StuffToRemoveLater.voidpos.Position = Vector3.new(0, -100000, 0)
	StuffToRemoveLater.voidpos.Name = "VoidPos"

	function handleMandrake(mandrake)
		if mandrake.Name == "Mandrake" and mandrake:WaitForChild("ModulePrompt", 1) and mandrake:WaitForChild("KilledEvent", 1) and mandrake:WaitForChild("Root", 1) then
			local pos = StuffToRemoveLater.voidpos:Clone()
			pos.Parent = mandrake.Root
			Variables.MandrakesPos[mandrake] = pos
			mandrake.Goal.GoalAttach.CFrame = CFrame.new(0,-100000,0)
		end
	end

	local function getDirFunction()
		local connections = getconnections and getconnections(TargetCameraDirection.OnClientEvent)
		local connection = connections and connections[1]
		return connection and connection.Function
	end

	Variables.AutoMandrake = Library.Toggles.AutoMandrake
	Variables.DeleteMandrake = Library.Toggles.DeleteMandrake
	Toggles.DisableMandrakeFEAlt = NoAltFeatures() or (Floor ~= "Garden" and {Value = false}) or Groupbox:AddToggle(prefix..'DisableMandrakeFEAlt', {
		Text = 'Disable Mandrake Alt [FE]',
		Default = false,

		Callback = function(value)
			if value then
				toggleNetworkOwner(true)
				Variables.dirFunction = getDirFunction()
				if hookfunction then
					if Variables.dirFunction then
						hookfunction(Variables.dirFunction, function()end)
					end
					hookfunction(TargetCameraDirection.OnClientEvent.Connect, function()end)
				end
				if Variables.AutoMandrake then
					if Variables.AutoMandrake.Value then
						Variables.AutoMandrake:SetValue(false)
					end
					Variables.AutoMandrake:SetDisabled(true)
				end
				if Variables.DeleteMandrake.Value then
					Variables.DeleteMandrake:SetValue(false)
				end
				Variables.DeleteMandrake:SetDisabled(true)
				for _, mandrake in CurrentRooms:QueryDescendants("#Mandrake") do
					handleMandrake(mandrake)
				end
				Connections.MandrakeAddedConnection = CurrentRooms.DescendantAdded:Connect(handleMandrake)
				Connections.MandrakeRemovedConnection = CurrentRooms.DescendantRemoving:Connect(function(mandrake)
					if mandrake.Name == "Mandrake" and mandrake:WaitForChild("ModulePrompt", 1) and mandrake:WaitForChild("KilledEvent", 1) and MandrakesVel[mandrake] then
						Variables.MandrakesPos[mandrake]:Destroy()
						Variables.MandrakesPos[mandrake] = nil
					end
				end)
			else
				toggleNetworkOwner(false)
				if isfunctionhooked and restorefunction then
					if Variables.dirFunction and isfunctionhooked(Variables.dirFunction) then
						restorefunction(Variables.dirFunction)
					end
					if isfunctionhooked(TargetCameraDirection.OnClientEvent.Connect) then
						restorefunction(TargetCameraDirection.OnClientEvent.Connect)
					end
				end
				if Variables.AutoMandrake then
					Variables.AutoMandrake:SetDisabled(false)
				end
				Variables.DeleteMandrake:SetDisabled(false)
				if Connections.MandrakeAddedConnection then
					Connections.MandrakeAddedConnection:Disconnect()
					Connections.MandrakeAddedConnection = nil
				end
				if Connections.MandrakeRemovedConnection then
					Connections.MandrakeRemovedConnection:Disconnect()
					Connections.MandrakeRemovedConnection = nil
				end
				for mandrake, pos in Variables.MandrakesPos do
					pos:Destroy()
					Variables.MandrakesPos[mandrake] = nil
					mandrake.Goal.GoalAttach.CFrame = CFrame.new(0,0,0)
				end
			end
		end
	})

	Variables.spoofed = false
	Toggles.AntiGroundskeeper = Groupbox:AddToggle(prefix..'AntiGroundskeeper', {
		Text = 'Anti Groundskeeper',
		Default = false,

		Callback = function(value)
			if value then
				if Toggles.InfiniteCrucifixAlt.Value then
					Toggles.InfiniteCrucifixAlt:SetValue(false)
				end
				if Toggles.CollisionOffsetGodmodeAlt.Value then
					Toggles.CollisionOffsetGodmodeAlt:SetValue(false)
				end
				Connections.AGS = Services.RunService.Heartbeat:Connect(function()
					local HumanoidRootPart = Character and Character:FindFirstChild("HumanoidRootPart")
					if HumanoidRootPart and ShouldSpoofGS(HumanoidRootPart) and not killPlayerWF.Disabled then
						if not Variables.spoofed then
							DoStuffWithAntiTp()
						end
						Variables.spoofed = true
						HumanoidRootPart.CFrame *= CFrame.new(0, 3, 0)
						Services.RunService.RenderStepped:Wait()
						HumanoidRootPart.CFrame *= CFrame.new(0, -3, 0)
						Camera.CFrame -= Vector3.new(0,3,0)
					else
						Variables.spoofed = false
					end
				end)
			else
				if Connections.AGS then
					if Variables.spoofed then
						DoStuffWithAntiTp()
					end
					Connections.AGS:Disconnect()
					Connections.AGS = nil
					Variables.spoofed = false
				end
			end
		end
	})

	Variables.spoofed2 = false
	Toggles.AntiFigure = Groupbox:AddToggle(prefix..'AntiFigure', {
		Text = 'Anti Figure',
		Default = false,

		Callback = function(value)
			if value then
				if Toggles.InfiniteCrucifixAlt.Value then
					Toggles.InfiniteCrucifixAlt:SetValue(false)
				end
				if Toggles.CollisionOffsetGodmodeAlt.Value then
					Toggles.CollisionOffsetGodmodeAlt:SetValue(false)
				end
				Connections.AFR = Services.RunService.Heartbeat:Connect(function()
					local HumanoidRootPart = Character and Character:FindFirstChild("HumanoidRootPart")
					local offset = 9.5-(Toggles.AntiGroundskeeper.Value and ShouldSpoofGS(HumanoidRootPart) and 3 or 0)
					if HumanoidRootPart and ShouldSpoofFR(HumanoidRootPart) and not killPlayerWF.Disabled then
						if not Variables.spoofed2 then
							DoStuffWithAntiTp()
						end
						Variables.spoofed2 = true
						HumanoidRootPart.CFrame *= CFrame.new(0, offset, 0)
						Services.RunService.RenderStepped:Wait()
						HumanoidRootPart.CFrame *= CFrame.new(0, -offset, 0)
						Camera.CFrame -= Vector3.new(0,offset,0)
					else
						Variables.spoofed2 = false
					end
				end)
			else
				if Connections.AFR then
					if spoofed2 then
						DoStuffWithAntiTp()
					end
					Connections.AFR:Disconnect()
					Connections.AFR = nil
					spoofed2 = false
				end
			end
		end
	})

	Toggles.FlingCreak = Floor ~= "Stairwell" and {Value = false} or Groupbox:AddToggle(prefix..'FlingCreak', {
		Text = 'Fling Creak',
		DisabledTooltip = 'Executor is not supported',
		Tooltip = 'Tries to fling Creak using chair (bro why they added a ####### functional chair :sob:)',
		Risky = true,
		Default = false,
		Disabled = not sethiddenproperty,

		Callback = function(value)
			if value then
				Library:Notify({
					Title = "Tplay's Addon",
					Description = "Grab a chair to fling Creak",
					Time = 10
				})
				Connections.OnChairGrabCreak = Character.DescendantAdded:Connect(function(descendant)
					if descendant:IsA("Attachment") and descendant.Name == "CartTargetAttachment" and descendant.Parent.Name == "CollisionPart" then
						local chair = FindChair(descendant)
						local promptBlock = chair and chair:FindFirstChild("PromptBlocker")
						if promptBlock then
							if chair == Variables.ChairThatFlingsCreak then
								CartControl:FireServer()
								return
							elseif Variables.ChairThatFlingsCreak then
								return
							elseif not Variables.ChairThatFlingsCreak then
								CartControl:FireServer()
							end
							Library:Notify({
								Title = "Tplay's Addon",
								Description = "Chair is ready to fling Creak",
								Time = 3
							})
							Variables.ChairThatFlingsCreak = chair
							task.wait()
							chair = Variables.ChairThatFlingsCreak
							local oldcframe = chair:GetPivot()
							local killed = false
							Variables.FlingingCreak = true
							while Variables.FlingingCreak and chair and chair.Parent and promptBlock and isnetworkowner(promptBlock) do
								local creak = LiveEntities:FindFirstChild("Creak")
								if creak then
									local part = creak:FindFirstChild("HumanoidRootPart") or creak.PrimaryPart or creak:FindFirstChildWhichIsA("BasePart")
									if not part then
										killed = true
										break
									end
									pcall(sethiddenproperty, promptBlock, "PhysicsRepRootPart", part)
									chair:PivotTo(creak:GetPivot()+Vector3.new(0,3,0))
    								chair.Collider.AssemblyLinearVelocity = Vector3.new(0,-math.random(500000,1000000),0)
								end
								task.wait()
								chair = Variables.ChairThatFlingsCreak
								promptBlock = chair and chair:FindFirstChild("PromptBlocker")
							end
							if chair then
								chair:PivotTo(oldcframe)
							end
							Variables.ChairThatFlingsCreak = nil
							if killed then
								Library:Notify({
									Title = "Tplay's Addon",
									Description = "Creak was deleted while flinging, now you can play Stairwell and don't worry about Creak",
									Time = 10
								})
							elseif Variables.FlingingCreak then
								Library:Notify({
									Title = "Tplay's Addon [Warning]",
									Description = "Something happened with chair that caused it to not fling Creak anymore, grab another chair to continue flinging",
									Time = 10
								})
							else
								Library:Notify({
									Title = "Tplay's Addon",
									Description = "Removed control from the chair that was flinging Creak",
									Time = 5
								})
							end
							Variables.FlingingCreak = false
						end
					end
				end)
			else
				if Connections.OnChairGrabCreak then
					Connections.OnChairGrabCreak:Disconnect()
					Connections.OnChairGrabCreak = nil
				end
				if Variables.FlingingCreak then
					Variables.FlingingCreak = false
				end
			end
		end
	})

	Groupbox:AddDivider({
		Text = "AUTO COMPLETE",
		MarginTop = 4,
		MarginBottom = 0
	})

    Variables.MrHFloorMode = "1 - Normal"
    local mrhPausedDoorReach = nil
    local mrhThreatNames = {
        RushMoving=true, AmbushMoving=true, BackdoorRush=true,
        A60=true, A120=true, Dread=true, Eyes=true, SeekMoving=true,
    }
    local function mrhEntityPresent()
        for _, object in ipairs(workspace:GetChildren()) do
            if mrhThreatNames[object.Name] then return true end
        end
        if LiveEntities then
            for _, object in ipairs(LiveEntities:GetChildren()) do
                if mrhThreatNames[object.Name] then return true end
            end
        end
        return false
    end
    local function mrhReleasePause()
        if mrhPausedDoorReach ~= nil then
            Library.Toggles.DoorReach:SetValue(mrhPausedDoorReach)
            mrhPausedDoorReach = nil
        end
    end
    local function MrHShouldPauseAutoFloor()
        if Variables.MrHFloorMode ~= "2 - Safe" or not mrhEntityPresent() then
            mrhReleasePause()
            return false
        end
        local reach = Library.Toggles.DoorReach
        if mrhPausedDoorReach == nil then mrhPausedDoorReach = reach.Value end
        if reach.Value then reach:SetValue(false) end
        return true
    end
    local function MrHAutoFloorPivot(frame)
        if not MrHShouldPauseAutoFloor() then Character:PivotTo(frame) end
    end
    Groupbox:AddDropdown(prefix.."AutoFloorMethod", {
        Text="Auto Floor Method",
        Values={"1 - Normal", "2 - Safe", "3 - Rush"},
        Default=1, Multi=false,
        Tooltip="Normal: original tplay behavior. Safe: pause while a detected entity exists. Rush: ignore entity proximity; cutscene and floor mechanics still apply.",
        Callback=function(value)
            Variables.MrHFloorMode=value
            if value ~= "2 - Safe" then mrhReleasePause() end
        end
    })
    OnUnload(mrhReleasePause)

	Variables.AutoFloorDist = {
		RushMoving = 120,
		AmbushMoving = 180,
		BackdoorRush = 108,
		["A60"] = 180
	}

	function ActiveRusher(interesting)
        if Variables.MrHFloorMode == "3 - Rush" then return false end
		local Room = CurrentRooms:FindFirstChild(LatestRoom.Value)
		local Door = Room and Room:FindFirstChild("Door")
		local PrevRoom = CurrentRooms:FindFirstChild(LatestRoom.Value-1)
		local PrevDoor = PrevRoom and PrevRoom:FindFirstChild("Door")
		local PrevPrevRoom = CurrentRooms:FindFirstChild(LatestRoom.Value-2)
		local PrevPrevDoor = PrevPrevRoom and PrevPrevRoom:FindFirstChild("Door")
		for _, rusher in workspace:QueryDescendants("> #RushMoving, > #AmbushMoving, > #A60, > #BackdoorRush") do
			if interesting or (Character:GetPivot().Position-rusher:GetPivot().Position).Magnitude < Variables.AutoFloorDist[rusher.Name] or (Door and (Door:GetPivot().Position-rusher:GetPivot().Position).Magnitude < Variables.AutoFloorDist[rusher.Name]) or (PrevDoor and (PrevDoor:GetPivot().Position-rusher:GetPivot().Position).Magnitude < Variables.AutoFloorDist[rusher.Name]) or (PrevPrevDoor and (PrevPrevDoor:GetPivot().Position-rusher:GetPivot().Position).Magnitude < Variables.AutoFloorDist[rusher.Name]) then
				return true
			end
		end
		return false
	end

	function GetDropThatCanUnlock()
		for i,v in Drops:QueryDescendants(`Model[$PlayerName = {LocalPlayer.Name}]`) do
			if v.Name == "Lockpick" or v.Name == "SkeletonKey" or v.Name == "Multitool" then
				return v
			end
		end
		return nil
	end

	function ItemThatCanUnlock()
		local Backpack = LocalPlayer.Backpack
		local Tool = GetEquippedTool(LocalPlayer)
		return Tool
		and (Tool.Name == "Lockpick" or Tool.Name == "SkeletonKey" or Tool.Name == "Multitool")
		and Tool
		or GetDropThatCanUnlock()
		or Backpack:FindFirstChild("Lockpick")
		or Backpack:FindFirstChild("SkeletonKey")
		or Backpack:FindFirstChild("Multitool")
	end

	function FindKeyObtain(Room)
		local key = Room:FindFirstChild("KeyObtain", true)
		if key then
			return key, key.Parent.Name == "DrawerContainer" and key.Parent
		end
		return nil, false
	end

	function GetNearestBook(Room)
		local Nearest = {
			Dist = 1/0
		}
		for _, book in Room:QueryDescendants("#Modular_Bookshelf > #LiveHintBook") do
			local dist = (Character:GetPivot().Position-book:GetPivot().Position).Magnitude
			if dist < Nearest.Dist then
				Nearest.Dist = dist
				Nearest.Book = book
			end
		end
		return Nearest.Book
	end

	function GetNearestBreaker(Room)
		local Nearest = {
			Dist = 1/0
		}
		for _, breaker in Room:QueryDescendants("#LiveBreakerPolePickup") do
			local dist = (Character:GetPivot().Position-breaker:GetPivot().Position).Magnitude
			if dist < Nearest.Dist then
				Nearest.Dist = dist
				Nearest.Breaker = breaker
			end
		end
		return Nearest.Breaker or Room:FindFirstChild("LiveBreakerPolePickup")
	end

	function GetNearestFuse(Room)
		local Nearest = {
			Dist = 1/0
		}
		for _, fuse in Room:QueryDescendants("#FuseObtain") do
			local dist = (Character:GetPivot().Position-fuse:GetPivot().Position).Magnitude
			if dist < Nearest.Dist and fuse.Hitbox.FuseModel.LocalTransparencyModifier ~= 1 then
				Nearest.Dist = dist
				Nearest.Fuse = fuse
			end
		end
		return Nearest.Fuse
	end

	Variables.InfItems = Library.Toggles.InfItems
	Variables.AutoLibrarySolver = Library.Toggles.AutoLibrarySolver
	Variables.BruteforceLibraryCode = Library.Toggles.BruteforceLibraryCode
	Variables.AutoBreakerSolverMethod = Library.Options.AutoBreakerSolverMethod
	Variables.AutoBreakerSolver = Library.Toggles.AutoBreakerSolver
	Variables.StuffToKeepEnabled = {
		Library.Toggles.AntiScreech,
		Library.Toggles.AntiDupe,
		Library.Toggles.AntiDread,
		Library.Toggles.AntiHalt,
		Library.Toggles.AntiSnare,
		Library.Toggles.AntiEyes,
		Library.Toggles.AntiA90,
		Library.Toggles.CollisionOffsetAutomatic,
		Library.Toggles.AutoInteract,
	}

	if Floor == "Mines" then
		for i, b in Library.Buttons do
			if b and b.Text == "Beat Door 200" then
				Variables.BeatDoor200 = b
				break
			end
		end
		table.insert(Variables.StuffToKeepEnabled, Library.Toggles.AntiSeekFlood)
		table.insert(Variables.StuffToKeepEnabled, Library.Toggles.AntiGiggle)
	elseif Floor == "Garden" then
		table.insert(Variables.StuffToKeepEnabled, Library.Toggles.NoSurgeDamage)
		table.insert(Variables.StuffToKeepEnabled, Toggles.BringDrawers)
		table.insert(Variables.StuffToKeepEnabled, Toggles.AutoLoot)
	elseif `{Floor}_{FloorSpecific}` == "Ripple_Daily_Default" then
	else
		table.insert(Variables.StuffToKeepEnabled, Toggles.BringDrawers)
		table.insert(Variables.StuffToKeepEnabled, Toggles.AutoLoot)
	end

	function IsInteresting(Rooms, Room)
		return not not (table.find(Rooms, Room:GetAttribute("RawName")) or table.find(Rooms, `{Room:GetAttribute("RawName")}|{Room.Name}`) or table.find(Rooms, Room.Name))
	end

	function GetNearestLadderGrabPart(Room)
		local Nearest = {
			Dist = 1/0
		}
		for _, grabPart in Room:QueryDescendants("#Ladder > #GrabPart") do
			local dist = (Character:GetPivot().Position-grabPart.Position).Magnitude
			if dist < Nearest.Dist then
				Nearest.Dist = dist
				Nearest.GrabPart = grabPart
			end
		end
		return Nearest.GrabPart
	end

	function GetNearestLever(Room)
		local Nearest = {
			Dist = 1/0
		}
		for _, lever in Room:QueryDescendants("#AlaskanVineSet > #VineGuillotine > #Lever") do
			local dist = (Character:GetPivot().Position-lever.Position).Magnitude
			if dist < Nearest.Dist and lever.ActivateEventPrompt.Enabled then
				Nearest.Dist = dist
				Nearest.Lever = lever
			end
		end
		return Nearest.Lever
	end

	function GetLotusPetal()
		local LotusPetals = CurrentRooms:QueryDescendants("#LotusHolder, #LotusPetalPickup, #LotusPetal")
		local LotusPetal, Drawer
		for _, lotuspetal in LotusPetals do
			if lotuspetal.ModulePrompt.Enabled then
				LotusPetal, Drawer = lotuspetal, lotuspetal.Parent and lotuspetal.Parent.Name == "DrawerContainer" and lotuspetal.Parent
				break
			end
		end
		return LotusPetal, Drawer
	end

	StuffToRemoveLater.novelocitybro = Instance.new("BodyVelocity")
	StuffToRemoveLater.novelocitybro.MaxForce = Vector3.new(1/0, 1/0, 1/0)
	StuffToRemoveLater.novelocitybro.Velocity = Vector3.zero

    -- Integrated Auto Rooms engine: scoped locals, one movement owner.
    local function createMrHPathfindEngine()
local Players = game:GetService("Players")
local WS = game:GetService("Workspace")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PF = game:GetService("PathfindingService")
local player = Players.LocalPlayer
local lib = mspaint.Library or Library
local enabled, unloaded, revision = false, false, 0
local controlsTab
local SPEED, CLEAR_DELAY = 40, 2
local dangerNames = { A60 = true, A120 = true, RushMoving = true, AmbushMoving = true, BackdoorRush = true }
local lockerNames = { Rooms_Locker = true, Rooms_Locker_Fridge = true, Locker_Large = true, Wardrobe = true, Toolshed = true }
local connections, lockers, savedSpeeds = {}, {}, {}
local route, visual, target, room, character, humanoid, root
local threatMode, hidden, lastThreat, pauseUntil = false, false, -math.huge, 0
local lastPrompt, lastExit, retryAt, lastProgress = 0, 0, 0, 0
local progressPosition, waypointIndex, blockedConnection
local statusLabel, previousStatus, worker, lastError
local movementGoal
local movementMethod, lastTP = "Pathfind", -math.huge
local stopOnDoor, stopDoor, autoRoomsToggle = false, 1000, nil
local pathColor = Color3.fromRGB(0, 255, 170)
local turnCamera, smoothCamera = false, false
local cameraRotation, lastCamera
local selectedLoot, lootPrompts, lootCooldown, lootAttempts = {}, {}, {}, {}
local lockerCooldown, hideAttempt = {}, nil
local lootNames = { StardustPickup = "Stardust", GoldPile = "Gold", Battery = "Batteries" }
local renderBinding = "MrHFloor_Movement_" .. game:GetService("HttpService"):GenerateGUID(false)

local function status(text)
    if text ~= previousStatus and not unloaded then
        previousStatus = text
        if statusLabel then statusLabel:SetText(text) end
    end
end

local function stopMovement()
    movementGoal = nil
    if humanoid and humanoid.Parent then
        humanoid.Jump = false
        humanoid:Move(Vector3.zero)
        if root and root.Parent then humanoid:MoveTo(root.Position) end
    end
end

local function clearRoute()
    if blockedConnection then blockedConnection:Disconnect() blockedConnection = nil end
    if route then route.path:Destroy() route = nil end
    if visual then visual:Destroy() visual = nil end
end

local function invalidate()
    revision = revision + 1
    target = nil
    hideAttempt = nil
    cameraRotation = nil
    clearRoute()
    stopMovement()
    retryAt = 0
    lastTP = -math.huge
end

local function restoreSpeeds()
    for h, speed in pairs(savedSpeeds) do
        if h.Parent then h.WalkSpeed = speed end
    end
    savedSpeeds = {}
end

local function setEnabled(value)
    enabled = value == true and not unloaded
    invalidate()
    if not enabled then restoreSpeeds() end
    status(enabled and "Starting..." or "Disabled")
end

local function cleanup()
    if unloaded then return end
    setEnabled(false)
    unloaded = true
    RunService:UnbindFromRenderStep(renderBinding)
    for _, c in ipairs(connections) do c:Disconnect() end
    if controlsTab then controlsTab:Destroy() controlsTab=nil end
    -- A pending ComputeAsync finishes and discards its result by revision.
end

local function getRoom()
    local rooms = WS:FindFirstChild("CurrentRooms")
    local number = player:GetAttribute("CurrentRoom")
    if not rooms then return nil end
    local current = number ~= nil and rooms:FindFirstChild(tostring(number))
    if current then return current end
    -- Some floors do not publish the player's CurrentRoom attribute.
    local data = RS:FindFirstChild("GameData")
    local latest = data and data:FindFirstChild("LatestRoom")
    return latest and rooms:FindFirstChild(tostring(latest.Value)) or nil
end

local function inRooms()
    local data = RS:FindFirstChild("GameData")
    return WS:FindFirstChild("CurrentRooms") ~= nil and game.PlaceId ~= 6516141723
end

local function checkStopDoor()
    if not enabled or not stopOnDoor or not inRooms() then return false end
    -- Use this player's progress, not LatestRoom (which a teammate can advance).
    local current = tonumber(player:GetAttribute("CurrentRoom"))
    if not current or current < stopDoor then return false end
    setEnabled(false)
    if autoRoomsToggle then autoRoomsToggle:SetValue(false) end
    status(string.format("Stopped at door %d (target %d).", current, stopDoor))
    return true
end

local function remotes()
    return RS:FindFirstChild("RemotesFolder") or RS:FindFirstChild("EntityInfo") or RS:FindFirstChild("Bricks")
end

local function promptPosition(prompt, model)
    local parent = prompt.Parent
    if parent and parent:IsA("Attachment") then return parent.WorldPosition end
    if parent and parent:IsA("BasePart") then return parent.Position end
    if model:IsA("BasePart") then return model.Position end
    return model.PrimaryPart and model.PrimaryPart.Position or model:GetPivot().Position
end

local function lockerData(model)
    if not model:IsDescendantOf(WS) or (lockerCooldown[model] or 0) > os.clock() then return nil end
    local occupancy = model:FindFirstChild("HiddenPlayer", true)
    -- Unknown/partially streamed occupancy is not proof that a locker is free.
    if not occupancy or not occupancy:IsA("ObjectValue") or occupancy.Value ~= nil then return nil end
    local prompt = model:FindFirstChild("HidePrompt", true)
    if not prompt or not prompt:IsA("ProximityPrompt") or not prompt.Enabled then return nil end
    return { model = model, prompt = prompt, position = promptPosition(prompt, model), kind = "locker" }
end

local function rejectLocker(model, reason)
    lockerCooldown[model] = os.clock() + 8
    invalidate()
    status(reason .. "; finding another locker...")
end

local function canEnterLocker(item)
    if not root or not item.prompt.Enabled then return false end
    local margin = math.max(0, item.prompt.MaxActivationDistance - 1)
    if (root.Position - item.position).Magnitude > margin then return false end
    -- Being inside the prompt radius through a wall is not a reachable entry.
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = visual and { character, visual } or { character }
    params.RespectCanCollide = true
    local hit = WS:Raycast(root.Position, item.position - root.Position, params)
    return not hit or hit.Instance:IsDescendantOf(item.model) or hit.Instance == item.model
end

local function activeThreat()
    for _, object in ipairs(WS:GetChildren()) do
        if dangerNames[object.Name] then
            local part = object:IsA("Model") and object.PrimaryPart or (object:IsA("BasePart") and object)
            if Floor ~= "Rooms" or not part or (part.Position.Y > -10 and part.Position.Y < 150) then return true end
        end
    end
    return false
end

local function unsafeForLoot()
    return threatMode or activeThreat() or hidden or os.clock() < pauseUntil
        or (character and character:GetAttribute("Hiding") == true)
end

local function lootData(prompt)
    if not room or not prompt:IsDescendantOf(room) or not prompt.Enabled
        or (lootCooldown[prompt] or 0) > os.clock() then return nil end
    local item = prompt.Parent
    while item and item ~= room do
        if item:GetAttribute("JeffShop") then return nil end
        local category = lootNames[item.Name]
        if category and selectedLoot[category] then
            if not item:IsA("Model") and not item:IsA("BasePart") then return nil end
            return { model = item, prompt = prompt, position = promptPosition(prompt, item), kind = "loot", category = category }
        end
        item = item.Parent
    end
    return nil
end

local function ground(point, exclude)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = exclude
    params.RespectCanCollide = true
    local hit = WS:Raycast(point + Vector3.new(0, 4, 0), Vector3.new(0, -20, 0), params)
    return hit and hit.Position or point
end

local function showPath(points, kind)
    if visual then visual:Destroy() end
    visual = Instance.new("Folder")
    visual.Name = "MrHFloor_Path"
    local anchor = Instance.new("Part")
    anchor.Anchored, anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = true, false, false, false
    anchor.Size, anchor.Transparency = Vector3.new(0.1, 0.1, 0.1), 1
    anchor.CFrame = CFrame.new(points[1].Position)
    anchor.Parent = visual
    local previous
    for _, waypoint in ipairs(points) do
        local attachment = Instance.new("Attachment")
        attachment.Position = anchor.CFrame:PointToObjectSpace(waypoint.Position + Vector3.new(0, 0.25, 0))
        attachment.Parent = anchor
        if previous then
            local beam = Instance.new("Beam")
            beam.Attachment0, beam.Attachment1 = previous, attachment
            beam.Width0, beam.Width1, beam.FaceCamera = 0.16, 0.16, true
            beam.Color = ColorSequence.new(pathColor)
            beam.Transparency, beam.LightEmission = NumberSequence.new(0), 1
            beam.LightInfluence, beam.Segments = 0, 1
            beam.Parent = anchor
        end
        previous = attachment
    end
    visual.Parent = WS
end

-- Door movement copied from tplay v2.4.0 AutoFloor. The surrounding Rooms
-- controller supplies hiding, loot priority, A90 pauses and Stop On Door.
local function tplayDoorTeleport(Character, Door)
    Character:PivotTo(Door:GetPivot())
end

local function candidates()
    if threatMode then
        local list = {}
        for model in pairs(lockers) do
            local item = lockerData(model)
            if item then
                item.distance = (item.position - root.Position).Magnitude
                if item.distance < 750 then table.insert(list, item) end
            end
        end
        table.sort(list, function(a, b) return a.distance < b.distance end)
        return list
    end
    local list = {}
    if not unsafeForLoot() then
        for prompt in pairs(lootPrompts) do
            local item = lootData(prompt)
            if item then
                item.distance = (item.position - root.Position).Magnitude
                table.insert(list, item)
            end
        end
        table.sort(list, function(a, b) return a.distance < b.distance end)
    end
    local door = room and room:FindFirstChild("Door")
    local exit = room and room:FindFirstChild("RoomExit")
    if not (exit and exit:IsA("BasePart")) then
        exit = door and (door:IsA("BasePart") and door
            or door:FindFirstChild("Door", true) or door.PrimaryPart)
        if exit and not exit:IsA("BasePart") then exit = nil end
    end
    if exit then
        table.insert(list, { model = exit, door = door, position = exit.Position, kind = "door" })
    end
    return list
end

local function plan()
    local token, expectedCharacter, startRoot = revision, character, root
    local list = candidates()
    if #list == 0 then
        status(threatMode and "No available locker loaded; waiting." or "Waiting for the next door...")
        retryAt = os.clock() + 0.4
        return
    end
    for _, item in ipairs(list) do
        if token ~= revision or not enabled or unloaded then return end
        if item.kind ~= "locker" and activeThreat() then invalidate() return end
        if item.prompt and ((item.kind == "locker" and canEnterLocker(item))
            or (item.kind == "loot" and (root.Position - item.position).Magnitude <= math.max(0, item.prompt.MaxActivationDistance - 0.25))) then
            target = item
            stopMovement()
            return
        end
        local goals = {}
        local exclude = { expectedCharacter }
        if visual then table.insert(exclude, visual) end
        if item.kind == "locker" then
            -- Test both faces; never remove locker collision or path into its body.
            local pivot = item.model:GetPivot()
            local offset = math.min(3, math.max(1, item.prompt.MaxActivationDistance * 0.65))
            local direction = Vector3.new(pivot.LookVector.X, 0, pivot.LookVector.Z)
            if direction.Magnitude < 0.01 then direction = Vector3.new(0, 0, 1) end
            direction = direction.Unit * offset
            goals = { item.position + direction, item.position - direction }
            table.sort(goals, function(a, b) return (a - startRoot.Position).Magnitude < (b - startRoot.Position).Magnitude end)
        elseif item.kind == "loot" then
            -- Try a point on the player's side of the pickup, then its floor
            -- position, rather than navigating into a table or container.
            local delta = startRoot.Position - item.position
            local flat = Vector3.new(delta.X, 0, delta.Z)
            local offset = math.min(2, item.prompt.MaxActivationDistance * 0.5)
            local direction = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(1, 0, 0)
            goals = { item.position + direction * offset, item.position }
        else
            -- Approach a closed door from this room's side, so its collision
            -- does not make the navigation endpoint unreachable.
            local entrance = room:FindFirstChild("RoomEntrance")
            local inside = entrance and entrance:IsA("BasePart") and entrance.Position or startRoot.Position
            local normal = Vector3.new(item.model.CFrame.LookVector.X, 0, item.model.CFrame.LookVector.Z)
            if normal.Magnitude < 0.01 then normal = Vector3.new(0, 0, 1) end
            normal = normal.Unit
            if (inside - item.position):Dot(normal) < 0 then normal = -normal end
            item.crossing = item.position - normal * 3
            goals = { item.position + normal * 4, item.position + normal * 7 }
        end
        for _, goal in ipairs(goals) do
            if movementMethod == "TP" then
                -- Use tplay's exact Door pivot for door TP. Locker/loot approach
                -- points belong to this addon's priority controller.
                if item.kind ~= "locker" and activeThreat() then invalidate() return end
                local destination = item.kind == "door" and item.crossing or goal
                local height = humanoid.HipHeight + root.Size.Y * 0.5
                item.tpGoal = ground(destination, exclude) + Vector3.new(0, height, 0)
                if item.kind == "door" and item.door then
                    item.tpGoal = item.door:GetPivot().Position
                end
                item.tpStarted = os.clock()
                target = item
                clearRoute()
                showPath({ { Position = startRoot.Position }, { Position = item.tpGoal } }, item.kind)
                status("TP to " .. (item.kind == "locker" and "locker" or item.kind == "loot" and item.category or "next door"))
                return
            end
            local path = PF:CreatePath({ AgentRadius = 1.5, AgentHeight = 4, AgentCanJump = true, WaypointSpacing = 3 })
            local ok, waypoints = pcall(function()
                path:ComputeAsync(startRoot.Position, ground(goal, exclude) + Vector3.new(0, 2, 0))
                if path.Status == Enum.PathStatus.Success then return path:GetWaypoints() end
            end)
            if token ~= revision or not enabled or unloaded or player.Character ~= expectedCharacter then
                path:Destroy()
                return
            end
            if item.kind ~= "locker" and activeThreat() then path:Destroy() invalidate() return end
            if ok and waypoints and #waypoints >= 2 then
                if item.kind == "locker" and not lockerData(item.model) then path:Destroy() break end
                if item.kind == "loot" and (unsafeForLoot() or not lootData(item.prompt)) then path:Destroy() break end
                clearRoute()
                target, route, waypointIndex = item, { path = path, points = waypoints }, 2
                progressPosition, lastProgress = root.Position, os.clock()
                blockedConnection = path.Blocked:Connect(function(index)
                    if index >= waypointIndex then invalidate() end
                end)
                showPath(waypoints, item.kind)
                status(item.kind == "locker" and "Entity detected: moving to locker"
                    or (item.kind == "loot" and "Collecting " .. item.category or "Walking to the next door — speed 40"))
                return
            end
            path:Destroy()
        end
        if item.kind == "loot" then lootCooldown[item.prompt] = os.clock() + 10 end
        if item.kind == "locker" then lockerCooldown[item.model] = os.clock() + 3 end
    end
    status(threatMode and "No reachable locker; retrying..." or "Door route blocked; retrying...")
    retryAt = os.clock() + 0.5
end

local function tickController()
    if not enabled or unloaded then return end
    if lib and lib.Unloaded then cleanup() return end
    if checkStopDoor() then return end
    if not inRooms() then
        if route or character then invalidate() restoreSpeeds() character = nil end
        status("Waiting for loaded rooms...")
        return
    end
    local newCharacter = player.Character
    local newHumanoid = newCharacter and newCharacter:FindFirstChildOfClass("Humanoid")
    local newRoot = newCharacter and newCharacter:FindFirstChild("HumanoidRootPart")
    if newCharacter ~= character or newHumanoid ~= humanoid or newRoot ~= root then
        invalidate()
        restoreSpeeds()
        character, humanoid, root = newCharacter, newHumanoid, newRoot
    end
    if not root or not humanoid or humanoid.Health <= 0 then
        invalidate()
        restoreSpeeds()
        status("Waiting for your character...")
        return
    end
    local now = os.clock()
    local foundThreat = activeThreat()
    if foundThreat then lastThreat = now end
    local newThreat = foundThreat or now - lastThreat < CLEAR_DELAY
    local newRoom = getRoom()
    if not newRoom then
        invalidate()
        status("Waiting for current room: CurrentRoom / LatestRoom unavailable.")
        return
    end
    local newHidden = character:GetAttribute("Hiding") == true
    if newThreat ~= threatMode or newRoom ~= room or newHidden ~= hidden then
        invalidate()
        threatMode, room, hidden = newThreat, newRoom, newHidden
    end
    if savedSpeeds[humanoid] == nil then savedSpeeds[humanoid] = humanoid.WalkSpeed end
    if now < pauseUntil then
        humanoid.WalkSpeed = 0
        stopMovement()
        status("A-90: holding still")
        return
    end
    humanoid.WalkSpeed = SPEED
    if hidden then
        stopMovement()
        if threatMode then status("Hiding until the entity clears") return end
        local folder = remotes()
        local remote = folder and folder:FindFirstChild("CamLock")
        if remote and remote:IsA("RemoteEvent") then
            if now - lastExit > 1 then lastExit = now remote:FireServer() end
            status("Leaving locker...")
        else
            status("Exit remote unavailable; leave the locker manually.")
        end
        return
    end
    -- A single entry request is outstanding. Never spam the prompt or treat
    -- firing it as success. Only the game's Hiding attribute confirms entry.
    if hideAttempt then
        local attempt = hideAttempt
        stopMovement()
        local occupancy = attempt.model:FindFirstChild("HiddenPlayer", true)
        if not attempt.model:IsDescendantOf(WS) or not attempt.prompt.Parent then
            rejectLocker(attempt.model, "Locker disappeared")
        elseif occupancy and occupancy:IsA("ObjectValue") and occupancy.Value ~= nil
            and occupancy.Value ~= character and occupancy.Value ~= player then
            rejectLocker(attempt.model, "Locker taken by another player")
        elseif now >= attempt.deadline then
            rejectLocker(attempt.model, "Hide was not confirmed")
        else
            status("Waiting for locker entry confirmation...")
        end
        return
    end
    -- Never interact with loot until the threat and its clear-delay have ended.
    if target and target.kind == "loot" then
        if unsafeForLoot() then invalidate() return end
        local item = lootData(target.prompt)
        if not item then invalidate() return end
        target.position = item.position
        if (root.Position - item.position).Magnitude <= math.max(0, item.prompt.MaxActivationDistance - 0.25) then
            stopMovement()
            status("Picking up " .. item.category)
            if now - lastPrompt >= 0.4 then
                lastPrompt = now
                local attempts = (lootAttempts[item.prompt] or 0) + 1
                lootAttempts[item.prompt] = attempts
                -- Recheck immediately before interacting: no yields between
                -- this guard and the prompt call, even if a path was pending.
                if unsafeForLoot() then invalidate() return end
                fireproximityprompt(item.prompt)
                if attempts >= 3 then
                    lootCooldown[item.prompt], lootAttempts[item.prompt] = os.clock() + 10, nil
                    invalidate()
                end
            end
            return
        end
    end
    if target and target.kind == "locker" then
        local item = lockerData(target.model)
        if not item then rejectLocker(target.model, "Locker unavailable") return end
        if canEnterLocker(item) then
            stopMovement()
            local hold = item.prompt.HoldDuration
            local attempt = { model = item.model, prompt = item.prompt,
                deadline = now + math.max(1.2, hold + 0.8), token = revision }
            hideAttempt = attempt
            status("Requesting locker entry...")
            local ok = pcall(fireproximityprompt, item.prompt, hold)
            if not ok and hideAttempt == attempt and revision == attempt.token then
                rejectLocker(item.model, "Hide interaction failed")
            end
            return
        end
    end
    if movementMethod == "TP" and target and target.tpGoal then
        stopMovement()
        local collision = character:FindFirstChild("Collision", true)
        if root.Anchored or (collision and collision:IsA("BasePart") and collision.Anchored)
            or humanoid.PlatformStand or humanoid.Sit then
            status("TP paused: character immobilized.")
            return
        end
        if now - target.tpStarted > 3 then
            if target.kind == "locker" then
                rejectLocker(target.model, "TP locker entry unavailable")
            else
                if target.kind == "loot" then lootCooldown[target.prompt] = now + 10 end
                invalidate()
                retryAt = now + 0.5
                status("TP not confirmed; retrying. Server may reject teleporting.")
            end
            return
        end
        if target.kind == "door" or now - lastTP >= 0.35 then
            if target.kind ~= "locker" and unsafeForLoot() then invalidate() return end
            lastTP = now
            if target.kind == "door" then
                local Door = target.door
                if not Door or not Door:IsDescendantOf(WS) then
                    invalidate()
                    status("Waiting for the door model to load...")
                    return
                end
                -- Original AutoFloor action, repeated on Heartbeat.
                tplayDoorTeleport(character, Door)
            else
                character:PivotTo(character:GetPivot() + (target.tpGoal - root.Position))
            end
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
        return
    end
    -- An in-range target can be selected without a path. Replan if it moves
    -- or the character is pushed outside its interaction range.
    if target and not route then invalidate() return end
    if route then
        if target.kind == "door" and (root.Position - target.position).Magnitude < 6 then
            -- Advance through the threshold using normal walking/proximity opening.
            movementGoal = target.crossing or target.position
            if now - lastProgress > 2 then invalidate() end
            return
        end
        local point = route.points[waypointIndex]
        if not point then
            if target.kind == "locker" then rejectLocker(target.model, "Locker entrance blocked") else invalidate() end
            return
        end
        local delta = root.Position - point.Position
        if Vector3.new(delta.X, 0, delta.Z).Magnitude < 2 and math.abs(delta.Y) < 6 then
            waypointIndex = waypointIndex + 1
            point = route.points[waypointIndex]
            if not point then
                if target.kind == "locker" then rejectLocker(target.model, "Locker entrance blocked") else invalidate() end
                return
            end
        end
        if point.Action == Enum.PathWaypointAction.Jump then humanoid.Jump = true end
        movementGoal = point.Position
        if (root.Position - progressPosition).Magnitude >= 1 then
            progressPosition, lastProgress = root.Position, now
        elseif now - lastProgress > 1.2 then
            if target.kind == "loot" then lootCooldown[target.prompt] = now + 10 end
            if target.kind == "locker" then rejectLocker(target.model, "Locker route blocked") return end
            invalidate()
            status("Recalculating blocked route...")
        end
    end
end

local function updateCamera(dt)
    if not turnCamera or not enabled or unloaded or not target or not inRooms()
        or not character or player.Character ~= character or not humanoid or humanoid.Health <= 0
        or character:GetAttribute("Hiding") == true or os.clock() < pauseUntil
        or (target.kind ~= "locker" and (threatMode or activeThreat())) then
        cameraRotation = nil
        return
    end
    local camera = WS.CurrentCamera
    if not camera or not target.model:IsDescendantOf(WS) then cameraRotation = nil return end
    if camera ~= lastCamera then cameraRotation, lastCamera = nil, camera end
    local aim = target.position
    if target.prompt and target.prompt.Parent then aim = promptPosition(target.prompt, target.model) end
    local position = camera.CFrame.Position
    local delta = aim - position
    if delta.Magnitude < 0.1 then return end
    local up = math.abs(delta.Unit.Y) > 0.999 and Vector3.new(0, 0, 1) or Vector3.new(0, 1, 0)
    local desired = CFrame.lookAt(position, aim, up).Rotation
    if smoothCamera then
        local alpha = 1 - math.exp(-10 * math.max(0, dt))
        cameraRotation = (cameraRotation or camera.CFrame.Rotation):Lerp(desired, alpha)
    else
        cameraRotation = desired
    end
    -- Preserve the game's camera position, type, subject, zoom and FOV.
    camera.CFrame = CFrame.new(position) * cameraRotation
end

-- Humanoid:Move from the default player controls can cancel MoveTo. Submit our
-- world-space steering after those controls each frame, while leaving their
-- enabled state untouched. Turning this addon off immediately releases movement.
local function driveMovement()
    if not enabled or unloaded or not inRooms() then return end
    if lib and lib.Unloaded then cleanup() return end
    if checkStopDoor() then return end
    if not character or player.Character ~= character or not humanoid or not root
        or not root.Parent or humanoid.Health <= 0 then return end
    if target and target.kind ~= "locker" and activeThreat() then invalidate() return end
    if os.clock() < pauseUntil or character:GetAttribute("Hiding") == true then
        humanoid:Move(Vector3.zero, false)
        if os.clock() < pauseUntil then humanoid.WalkSpeed = 0 end
        return
    end
    if not movementGoal then
        humanoid:Move(Vector3.zero, false)
        return
    end
    local collision = character:FindFirstChild("Collision", true)
    if root.Anchored or (collision and collision:IsA("BasePart") and collision.Anchored) then
        humanoid:Move(Vector3.zero, false)
        status("Movement blocked: character anchored. Leave hiding/cutscene first.")
        return
    end
    if humanoid.PlatformStand or humanoid.Sit then
        humanoid:Move(Vector3.zero, false)
        status("Movement blocked: character seated or immobilized.")
        return
    end
    local delta = movementGoal - root.Position
    local flat = Vector3.new(delta.X, 0, delta.Z)
    humanoid.WalkSpeed = SPEED
    humanoid:Move(flat.Magnitude > 0.5 and flat.Unit or Vector3.zero, false)
end

local function watchLocker(object)
    if object:IsA("Model") and lockerNames[object.Name] then lockers[object] = true end
    if object:IsA("ProximityPrompt") then lootPrompts[object] = true end
end
for _, object in ipairs(WS:GetDescendants()) do watchLocker(object) end
table.insert(connections, WS.DescendantAdded:Connect(watchLocker))
table.insert(connections, WS.DescendantRemoving:Connect(function(object)
    lockers[object], lootPrompts[object], lootCooldown[object], lootAttempts[object] = nil, nil, nil, nil
    lockerCooldown[object] = nil
end))

local seenA90 = {}
local function watchA90(object)
    if object.Name == "A90" and object:IsA("RemoteEvent") and not seenA90[object] then
        seenA90[object] = true
        table.insert(connections, object.OnClientEvent:Connect(function()
            if enabled then pauseUntil = os.clock() + 2 invalidate() end
        end))
    end
end
for _, object in ipairs(RS:GetDescendants()) do watchA90(object) end
table.insert(connections, RS.DescendantAdded:Connect(watchA90))

local box, credits, loot = mspaint.Groupbox, mspaint.Groupbox, mspaint.Groupbox
local settings = mspaint.Groupbox
if Window and type(Window.AddTab) == "function" then
    local tab = Window:AddTab("Auto Floor Settings", "route")
    controlsTab=tab
    box = tab:AddLeftGroupbox("Main")
    loot = tab:AddLeftGroupbox("Loot")
    settings = tab:AddRightGroupbox("Settings")
    credits = tab:AddRightGroupbox("Credits")
    box:AddLabel("Controlled by Main > Auto Floor. Pathfind navigates ordinary doors; floor puzzles may need manual completion or TP mode.", true)
else
    box:AddLabel("Main")
end
statusLabel = box:AddLabel("Disabled", true)
autoRoomsToggle = {SetValue=function(_,value)
    if not value then
        setEnabled(false)
        if Toggles.AutoFloor and Toggles.AutoFloor.Value then Toggles.AutoFloor:SetValue(false) end
    end
end}
local cameraToggle = box:AddToggle("MrHFloor_TurnCamera", {
    Text = "Turn camera on object",
    Default = false,
    Tooltip = "Look at the current door, locker or loot target.",
    Callback = function(value) turnCamera = value == true cameraRotation = nil end,
})
local cameraOptions = box:AddDependencyBox()
cameraOptions:AddToggle("MrHFloor_SmoothCamera", {
    Text = "Smooth Camera",
    Default = false,
    Callback = function(value) smoothCamera = value == true cameraRotation = nil end,
})
cameraOptions:SetupDependencies({ { cameraToggle, true } })
box:AddLabel("Pathfind speed: 40 | TP: direct teleport", true)
if settings == box then settings:AddDivider() settings:AddLabel("Settings") end
local stopToggle = settings:AddToggle("MrHFloor_StopOnDoor", {
    Text = "Stop On Door",
    Default = false,
    Tooltip = "Turn Auto Rooms off when you reach this room number or have already passed it.",
    Callback = function(value) stopOnDoor = value == true end,
})
local stopOptions = settings:AddDependencyBox()
local stopHint = stopOptions:AddLabel("Only numbers 2-1000", true)
local stopInput
stopInput = stopOptions:AddInput("MrHFloor_StopDoorNumber", {
    Text = "Door number",
    Default = "1000",
    Numeric = true,
    Finished = true,
    ClearTextOnFocus = false,
    Callback = function(value)
        local text = tostring(value)
        local number = text:match("^%d+$") and tonumber(text)
        if not number or number < 2 or number > 1000 then
            if stopInput then stopInput:SetValue(tostring(stopDoor)) end
            stopHint:SetText("Only numbers 2-1000. Previous value kept.")
            return
        end
        stopDoor = number
        stopHint:SetText("Only numbers 2-1000")
    end,
})
stopOptions:SetupDependencies({ { stopToggle, true } })
settings:AddLabel("Pathfind color"):AddColorPicker("MrHFloor_PathColor", {
    Default = pathColor,
    Title = "Pathfind color",
    Resizable = true,
    Callback = function(value)
        pathColor = value
        if visual then
            for _, object in ipairs(visual:GetDescendants()) do
                if object:IsA("Beam") then object.Color = ColorSequence.new(pathColor) end
            end
        end
    end,
})
if loot == box then loot:AddDivider() loot:AddLabel("Loot") end
loot:AddDropdown("MrHFloor_Loot", {
    Text = "Select loot",
    Values = { "Stardust", "Gold", "Batteries" },
    Multi = true,
    AllowNull = true,
    Tooltip = "Collect selected loot in the current room. Hiding always takes priority.",
    Callback = function(value)
        selectedLoot = type(value) == "table" and value or {}
        if enabled and not threatMode and not hidden and os.clock() >= pauseUntil then invalidate() end
    end,
})
loot:AddLabel("Priority: Hide first, selected loot next, then the door.", true)
if credits == box then credits:AddDivider() credits:AddLabel("Credits") end
credits:AddLabel('<font color="#FFFF00">Mr H - Owner</font>', true)
credits:AddLabel("chat gpt astra - uhhh idk", true)

local elapsed = 0
table.insert(connections, RunService.Heartbeat:Connect(function(dt)
    elapsed = elapsed + dt
    if elapsed < 0.05 then return end
    elapsed = 0
    local ok, reason = pcall(tickController)
    if not ok then
        invalidate()
        restoreSpeeds()
        status("Pathfind error: " .. tostring(reason))
        if reason ~= lastError then lastError = reason warn("[AutoRooms] " .. tostring(reason)) end
    end
end))
OnUnload(cleanup)
RunService:BindToRenderStep(renderBinding, Enum.RenderPriority.Last.Value + 1, function(dt)
    local ok, reason = pcall(driveMovement)
    if not ok then
        setEnabled(false)
        status("Movement error; see console.")
        warn("[AutoRooms movement] " .. tostring(reason))
    end
    local cameraOk, cameraError = pcall(updateCamera, dt)
    if not cameraOk then
        turnCamera, cameraRotation = false, nil
        warn("[AutoRooms camera] " .. tostring(cameraError))
    end
end)
worker = task.spawn(function()
    while not unloaded do
        if enabled and inRooms() and humanoid and humanoid.Health > 0 and root and room
            and not hidden and os.clock() >= pauseUntil and not route and not target and os.clock() >= retryAt then
            local ok, reason = pcall(plan)
            if not ok then
                invalidate()
                retryAt = os.clock() + 1
                status("Path calculation failed: " .. tostring(reason))
                if reason ~= lastError then lastError = reason warn("[AutoRooms] " .. tostring(reason)) end
            end
        end
        task.wait(0.1)
    end
end)

return {
    SetEnabled=function(value,method)
        if value and type(fireproximityprompt)~="function" then error("Auto Floor Pathfind requires fireproximityprompt") end
        movementMethod=method or "Pathfind"
        setEnabled(value)
    end,
    IsEnabled=function() return enabled end,
    Destroy=cleanup,
}

    end
    local mrhPathfindEngine=createMrHPathfindEngine()

	Variables.AutoFloors = {
		Hotel = {
			Requirements = {
				"firetouchinterest",
				"fireproximityprompt",
				"hookfunction",
				"restorefunction",
				"isfunctionhooked"
			},
			Callback = function(value)
				local InterestingRooms = {
					"Hotel_SeekIntro",
					"Hotel_LibraryEntrance",
					"99"
				}
				if value then
					if Toggles.AntiTeleport.Value then
						Toggles.AntiTeleport:SetValue(false)
					elseif Toggles.AntiTeleportRaknet.Value then
						Toggles.AntiTeleportRaknet:SetValue(false)
					end
					Services.RunService.RenderStepped:Wait()
					Toggles.AntiTeleport:SetDisabled(true)
					if not Toggles.AntiTeleportRaknet.Disabled then
						Toggles.AntiTeleportRaknet:SetDisabled(true)
					end
					Variables.tpFunction = getTpFunction()
					if hookfunction then
						if Variables.tpFunction then
							local tp; tp = hookfunction(Variables.tpFunction, function(...)
								if checkcaller() then
									tp(...)
								end
							end)
						end
						local hook; hook = hookfunction(ServerTeleported.OnClientEvent.Connect, function(self, func)
							if not checkcaller() then
								hookfunction(func, function()end)
								Variables.tpFunction = func
							end
							return hook(self, func)
						end)
					end
					local tempRoom = CurrentRooms:FindFirstChild(LatestRoom.Value)
					Variables.AutoFloorRoom = Library:Notify({
						Title = Info.AddonTitle,
						Description = `Doors opened: {LatestRoom.Value}\nCurrent room: {tempRoom and tempRoom:GetAttribute("RawName") or "?"}`,
						Persist = true
					})
					local AutoFloor = {}
					Connections.AutoFloor = AutoFloor
					local interesting = IsInteresting(InterestingRooms, tempRoom)
					local activeRusher = ActiveRusher(interesting)
					local lastCutscene = ""
					local lastCutsceneGlobal = ""
					local unavailableUntil = -1/0
					local touched = false
					local key, drawer, book, breaker
					AutoFloor.CutsceneActivatedGlobal = Cutscene.OnClientEvent:Connect(function(name)
						lastCutsceneGlobal = name
					end)
					AutoFloor.Teleporter = Services.RunService.Heartbeat:Connect(function()
                        if MrHShouldPauseAutoFloor() then return end
						if os.clock()<unavailableUntil or Character.PrimaryPart.Anchored then return end
						activeRusher = ActiveRusher(interesting)
						local Room = CurrentRooms:FindFirstChild(LatestRoom.Value)
						local Door = Room and Room:FindFirstChild("Door")
						if not Variables.slideSH then
							Variables.slideSH = true
							Crouch:FireServer(true,true)
						end
						for _, toggle in Variables.StuffToKeepEnabled do
							if not toggle.Value and not toggle.Disabled then
								toggle:SetValue(true)
							end
						end
						if activeRusher then
							if Library.Toggles.DoorReach.Value then
								Library.Toggles.DoorReach:SetValue(false)
							end
							return
						elseif Room:GetAttribute("RequiresKey") then
							local item = ItemThatCanUnlock()
							if item then
								if not Variables.InfItems.Value then
									Variables.InfItems:SetValue(true)
								end
								if item:IsA("Tool") and item.Parent ~= Character then
									item.Parent = Character
								elseif item:IsA("Model") then
									item:PivotTo(Character:GetPivot())
									fireproximityprompt(item.ModulePrompt)
								end
								MrHAutoFloorPivot(Door:GetPivot())
								local prompt = Door.Lock:FindFirstChild("UnlockPrompt") or Door.Lock:FindFirstChild("FakePrompt")
								if prompt then
									fireproximityprompt(prompt)
								end
							else
								local tool = GetEquippedTool(LocalPlayer)
								if LocalPlayer.Backpack:FindFirstChild("Key") or (tool and tool.Name == "Key") then
									key = nil
									drawer = nil
									MrHAutoFloorPivot(Door:GetPivot())
									local prompt = Door.Lock:FindFirstChild("UnlockPrompt") or Door.Lock:FindFirstChild("FakePrompt")
									if prompt then
										fireproximityprompt(prompt)
									end
								else
									if not key or not drawer then
										key, drawer = FindKeyObtain(Room)
									end
									if key then
										MrHAutoFloorPivot(drawer and drawer:GetPivot() or key:GetPivot())
										if drawer then
											fireproximityprompt(drawer.Knobs.ActivateEventPrompt)
										end
										fireproximityprompt(key.ModulePrompt)
									end
								end
							end
						elseif Room.Name == "50" then
							if bool ~= false then
								book = book and book.Parent and book or GetNearestBook(Room)
							end
							if book then
								MrHAutoFloorPivot(book:GetPivot()+Vector3.new(0,8,0))
								fireproximityprompt(book.ActivateEventPrompt)
							else
								book = false
								local tool = GetEquippedTool(LocalPlayer)
								local LibraryHintPaper = (tool and tool.Name == "LibraryHintPaper" and tool) or LocalPlayer.Backpack:FindFirstChild("LibraryHintPaper") or Room:FindFirstChild("LibraryHintPaper")
								if LibraryHintPaper then
									if LibraryHintPaper:IsA("Tool") then
										if not Variables.AutoLibrarySolver.Value then
											Variables.AutoLibrarySolver:SetValue(true)
										end
										if not Variables.BruteforceLibraryCode.Value then
											Variables.BruteforceLibraryCode:SetValue(true)
										end
										LibraryHintPaper.Parent = LibraryHintPaper.Parent == Character and LocalPlayer.Backpack or Character
										MrHAutoFloorPivot(Door:GetPivot())
									else
										MrHAutoFloorPivot(LibraryHintPaper:GetPivot()+Vector3.new(0,5,0))
										fireproximityprompt(LibraryHintPaper.ModulePrompt)
									end
								end
							end
						elseif Room.Name == "100" then
							if not AutoFloor.CutsceneActivated then
								AutoFloor.CutsceneActivated = Cutscene.OnClientEvent:Connect(function(name)
									lastCutscene = name
									if name == "Elevator1" then
										Library:Notify({
											Title = Info.AddonTitle,
											Description = "The hotel completed!",
											Time = 10
										})
										Toggles.AutoFloor:SetValue(false)
										Toggles.AutoFloor:SetDisabled(true)
										return
									end
								end)
							end
							if breaker ~= false then
								breaker = breaker and breaker.Parent and breaker or GetNearestBreaker(Room)
							end
							if breaker then
								MrHAutoFloorPivot(breaker:GetPivot())
								fireproximityprompt(breaker.ActivateEventPrompt)
							else
								breaker = false
								if lastCutscene == "" then
									MrHAutoFloorPivot(Room.IndustrialGate:GetPivot())
									fireproximityprompt(Room.IndustrialGate.Box.ActivateEventPrompt)
								elseif lastCutscene == "FigureHotelEnd" then
									toggleNetworkOwner(true)
									local pivot = Room.ElevatorBreakerEmpty:GetPivot()
									MrHAutoFloorPivot(pivot+pivot.RightVector*-12)
									fireproximityprompt(Room.ElevatorBreakerEmpty.Prompt)
									pcall(function()
										Room.FigureSetup.FigureRig:PivotTo(CFrame.new(0,-1000,0))
									end)
								elseif lastCutscene == "FigureHotelChase" then
									MrHAutoFloorPivot(Room.ElevatorCar.CollisionExtra.CFrame)
									firetouchinterest(Character.PrimaryPart, Room.ElevatorCar.CollisionExtra, touched and 1 or 0)
									touched = not touched
								elseif Room:FindFirstChild("ElevatorBreaker") then
									if not Variables.AutoBreakerSolver.Value then
										Variables.AutoBreakerSolver:SetValue(true)
									end
									if Variables.AutoBreakerSolverMethod.Value ~= "Exploit" then
										Variables.AutoBreakerSolverMethod:SetValue("Exploit")
									end
									MrHAutoFloorPivot(Room.ElevatorBreaker:GetPivot())
									fireproximityprompt(Room.ElevatorBreaker.ActivateEventPrompt)
								end
							end
						else
							MrHAutoFloorPivot(Door:GetPivot())
						end
						if not Library.Toggles.DoorReach.Value then
							Library.Toggles.DoorReach:SetValue(true)
						end
					end)
					AutoFloor.LatestRoomChanged = LatestRoom.Changed:Connect(function()
						room = CurrentRooms:FindFirstChild(LatestRoom.Value)
						if Variables.AutoFloorRoom then
							Variables.AutoFloorRoom:ChangeDescription(`Doors opened: {LatestRoom.Value}\nCurrent room: {room and room:GetAttribute("RawName") or "?"}`)
						end
						interesting = IsInteresting(InterestingRooms, room)
						if room and interesting then
							unavailableUntil = os.clock()+7
							while os.clock()<unavailableUntil and not activeRusher do
								activeRusher = ActiveRusher(interesting)
								Services.RunService.RenderStepped:Wait()
							end
						end
					end)
				else
					if Variables.AutoFloorRoom then
						Variables.AutoFloorRoom:Destroy()
					end
					Toggles.AntiTeleport:SetDisabled(false)
					if Variables.raknet_at_hook then
						Toggles.AntiTeleportRaknet:SetDisabled(false)
					end
					if isfunctionhooked and restorefunction then
						if Variables.tpFunction and isfunctionhooked(Variables.tpFunction) then
							restorefunction(Variables.tpFunction)
						end
						if isfunctionhooked(ServerTeleported.OnClientEvent.Connect) then
							restorefunction(ServerTeleported.OnClientEvent.Connect)
						end
					end
					if Connections.AutoFloor then
						for _, connection in Connections.AutoFloor do
							connection:Disconnect()
						end
						Connections.AutoFloor = nil
					end
				end
			end
		},
		Mines = {
			Requirements = {
				"firetouchinterest",
				"fireproximityprompt",
				"hookfunction",
				"restorefunction",
				"isfunctionhooked",
				"getrawmetatable",
				"setreadonly"
			},
			Callback = function(value)
				local InterestingRooms = {
					"Mines_SeekStart",
					"Sewer_SeekEnter",
					"98"
				}
				if value then
					if Toggles.AntiTeleport.Value then
						Toggles.AntiTeleport:SetValue(false)
					elseif Toggles.AntiTeleportRaknet.Value then
						Toggles.AntiTeleportRaknet:SetValue(false)
					end
					Services.RunService.RenderStepped:Wait()
					Toggles.AntiTeleport:SetDisabled(true)
					if not Toggles.AntiTeleportRaknet.Disabled then
						Toggles.AntiTeleportRaknet:SetDisabled(true)
					end
					Variables.tpFunction = getTpFunction()
					if hookfunction then
						if Variables.tpFunction then
							local tp; tp = hookfunction(Variables.tpFunction, function(...)
								if checkcaller() then
									tp(...)
								end
							end)
						end
						local hook; hook = hookfunction(ServerTeleported.OnClientEvent.Connect, function(self, func)
							if not checkcaller() then
								hookfunction(func, function()end)
								Variables.tpFunction = func
							end
							return hook(self, func)
						end)
					end
					local tempRoom = CurrentRooms:FindFirstChild(LatestRoom.Value)
					Variables.AutoFloorRoom = Library:Notify({
						Title = Info.AddonTitle,
						Description = `Doors opened: {LatestRoom.Value}\nCurrent room: {tempRoom and tempRoom:GetAttribute("RawName") or "?"}\nAnticheat bypass status: {Character:GetAttribute("_BypassedAC") and "ON" or "OFF"}`,
						Persist = true
					})
					local AutoFloor = {}
					Connections.AutoFloor = AutoFloor
					local interesting = IsInteresting(InterestingRooms, tempRoom)
					local activeRusher = ActiveRusher(interesting)
					local lastCutscene
					local unavailableUntil = -1/0
					local fuse, buttonPressed, leverActivated, beatingDoor200, noGeneratorSince, buggyRun
					AutoFloor.CutsceneActivated = Cutscene.OnClientEvent:Connect(function(name)
						lastCutscene = name
					end)
					AutoFloor.Teleporter = Services.RunService.Heartbeat:Connect(function()
                        if MrHShouldPauseAutoFloor() then return end
						if os.clock()<unavailableUntil or Character.PrimaryPart.Anchored or buggyRun then return end
						activeRusher = ActiveRusher(interesting)
						local Room = CurrentRooms:FindFirstChild(LatestRoom.Value)
						local Door = Room and Room:FindFirstChild("Door")
						if not Variables.slideSH then
							Variables.slideSH = true
							Crouch:FireServer(true,true)
						end
						for _, toggle in Variables.StuffToKeepEnabled do
							if not toggle.Value and not toggle.Disabled then
								toggle:SetValue(true)
							end
						end
						local grabPart = not Character:GetAttribute("_BypassedAC") and not (Camera and Camera:FindFirstChild("MinecartRig")) and GetNearestLadderGrabPart(Room)
						if activeRusher then
							if Library.Toggles.DoorReach.Value then
								Library.Toggles.DoorReach:SetValue(false)
							end
							return
						elseif Character:GetAttribute("Climbing") then
							Character:SetAttribute("Climbing")
							Character:SetAttribute("_BypassedAC", true)
							Connections.OnBypassRemove = Character:GetAttributeChangedSignal("Climbing"):Once(function()
								Character:SetAttribute("_BypassedAC", false)
								if Variables.AutoFloorRoom then
									Variables.AutoFloorRoom:ChangeDescription(`Doors opened: {LatestRoom.Value}\nCurrent room: {Room and Room:GetAttribute("RawName") or "?"}\nAnticheat bypass status: {Character:GetAttribute("_BypassedAC") and "ON" or "OFF"}`)
								end
							end)
							if Variables.AutoFloorRoom then
								Variables.AutoFloorRoom:ChangeDescription(`Doors opened: {LatestRoom.Value}\nCurrent room: {Room and Room:GetAttribute("RawName") or "?"}\nAnticheat bypass status: {Character:GetAttribute("_BypassedAC") and "ON" or "OFF"}`)
							end
						elseif grabPart then
							MrHAutoFloorPivot(grabPart.CFrame)
							fireproximityprompt(grabPart.ClimbPrompt)
						elseif Room.Name == "100" then
							if not AutoFloor.CutsceneActivated then
								AutoFloor.CutsceneActivated = Cutscene.OnClientEvent:Connect(function(name)
									lastCutscene = name
									if name == "MinesFinale" then
										Library:Notify({
											Title = Info.AddonTitle,
											Description = "The mines completed!",
											Time = 10
										})
										Toggles.AutoFloor:SetValue(false)
										Toggles.AutoFloor:SetDisabled(true)
										return
									end
								end)
							end
							if beatingDoor200 then
								if leverActivated and not buttonPressed then
									local button = Room.Assets.MinesGateButton.Button
									local prompt = button.ActivateEventPrompt
									MrHAutoFloorPivot(button.CFrame)
									fireproximityprompt(prompt)
									if button.SoundPress.Playing then
										buttonPressed = true
									end
								elseif not leverActivated then
									if Room.Assets.MinesGenerator.GeneratorMain.Sound.Playing then
										leverActivated = true
									end
								else
									local doors = Room._DamHandler._OutsideCutscene.DungeonDoor.DoubleDoors
									local prompt = doors.ActivateEventPrompt
									MrHAutoFloorPivot(doors:GetPivot())
									fireproximityprompt(prompt)
								end
							else
								beatingDoor200 = true
								pcall(Variables.BeatDoor200.Func)
							end
						elseif Room:GetAttribute("RequiresGenerator") then
							local fuse = GetNearestFuse(Room)
							if fuse then
								MrHAutoFloorPivot(fuse:GetPivot())
								local openFirst = fuse:FindFirstAncestor("Locker_Small") or fuse:FindFirstAncestor("DrawerContainer") or fuse:FindFirstAncestor("Toolbox")
								if openFirst then
									fireproximityprompt(openFirst:FindFirstChild("ActivateEventPrompt", true))
								end
								fireproximityprompt(fuse.ModulePrompt)
							else
								local gen = Room.Assets:FindFirstChild("MinesGenerator")
								if gen then
									noGeneratorSince = nil
								else
									noGeneratorSince = noGeneratorSince or os.clock()
									if noGeneratorSince < os.clock()-3 then
										buggyRun = true
										Library:Notify({
											Title = Info.AddonTitle,
											Description = "Generation bug detected: MinesGenerator didn't spawn in the room that requires generator\n(The game will be automatically restarted)",
											Persist = true
										})
										PlayAgain:FireServer()
									end
									return
								end
								local notTuff = false
								for _, fuse in gen.Fuses:GetChildren() do
									if tonumber(fuse.Name) and fuse.Fuse.Transparency == 1 then
										notTuff = true
										break
									end
								end
								local prompt = notTuff and (gen:FindFirstChild("FusesPrompt", true) or gen:FindFirstChild("FakePrompt", true))
								if prompt then
									MrHAutoFloorPivot(gen:GetPivot())
									fireproximityprompt(prompt)
								elseif not leverActivated then
									prompt = gen.Lever.LeverPrompt
									MrHAutoFloorPivot(gen:GetPivot())
									fireproximityprompt(prompt)
									if gen.GeneratorMain.Sound.Playing then
										leverActivated = true
									end
								elseif not buttonPressed then
									local button = Room.Assets.MinesGateButton.Button
									prompt = button.ActivateEventPrompt
									MrHAutoFloorPivot(button.CFrame)
									fireproximityprompt(prompt)
									if button.SoundPress.Playing then
										buttonPressed = true
									end
								else
									MrHAutoFloorPivot(Door:GetPivot())
								end
							end
						elseif Room.Name == "46" and not Camera:FindFirstChild("MinecartRig") then
							if not Toggles.MinecartChaseSkip.Value then
								Toggles.MinecartChaseSkip:SetValue(true)
							end
							MrHAutoFloorPivot(Room.MinecartCollision.Collision.CFrame)
							firetouchinterest(Character.PrimaryPart, Room.MinecartCollision.Collision, 0)
							firetouchinterest(Character.PrimaryPart, Room.MinecartCollision.Collision, 1)
							return
						elseif Camera:FindFirstChild("MinecartRig") and (tonumber(Room.Name) >= 46 or tonumber(Room.Name) < 50) then
							if not Toggles.MinecartChaseSkip.Value then
								Toggles.MinecartChaseSkip:SetValue(true)
							end
							return
						elseif Room.Name == "50" then
							if Camera:FindFirstChild("MinecartRig") then return end
							if buttonPressed then
								MrHAutoFloorPivot(Door:GetPivot())
							else
								local button = Room._NestHandler.Console.Button
								local prompt = button.ActivateEventPrompt
								MrHAutoFloorPivot(button.CFrame)
								fireproximityprompt(prompt)
								if button.SoundPress.Playing then
									buttonPressed = true
								end
							end
						else
							MrHAutoFloorPivot(Door:GetPivot())
						end
						if not Library.Toggles.DoorReach.Value then
							Library.Toggles.DoorReach:SetValue(true)
						end
					end)
					AutoFloor.LatestRoomChanged = LatestRoom.Changed:Connect(function()
						leverActivated = nil
						buttonPressed = nil
						room = CurrentRooms:FindFirstChild(LatestRoom.Value)
						if Variables.AutoFloorRoom then
							Variables.AutoFloorRoom:ChangeDescription(`Doors opened: {LatestRoom.Value}\nCurrent room: {room and room:GetAttribute("RawName") or "?"}\nAnticheat bypass status: {Character:GetAttribute("_BypassedAC") and "ON" or "OFF"}`)
						end
						interesting = IsInteresting(InterestingRooms, room)
						if room and interesting then
							unavailableUntil = os.clock()+7
							while os.clock()<unavailableUntil and not activeRusher do
								activeRusher = ActiveRusher(interesting)
								Services.RunService.RenderStepped:Wait()
							end
						end
					end)
				else
					if Variables.AutoFloorRoom then
						Variables.AutoFloorRoom:Destroy()
					end
					Toggles.AntiTeleport:SetDisabled(false)
					if Variables.raknet_at_hook then
						Toggles.AntiTeleportRaknet:SetDisabled(false)
					end
					if isfunctionhooked and restorefunction then
						if Variables.tpFunction and isfunctionhooked(Variables.tpFunction) then
							restorefunction(Variables.tpFunction)
						end
						if isfunctionhooked(ServerTeleported.OnClientEvent.Connect) then
							restorefunction(ServerTeleported.OnClientEvent.Connect)
						end
					end
					if Connections.AutoFloor then
						for _, connection in Connections.AutoFloor do
							connection:Disconnect()
						end
						Connections.AutoFloor = nil
					end
				end
			end
		},
		Endless = {
			Requirements = {
				"fireproximityprompt",
				"hookfunction",
				"restorefunction",
				"isfunctionhooked"
			},
			Callback = function(value)
				if value then
					if Toggles.AntiTeleport.Value then
						Toggles.AntiTeleport:SetValue(false)
					elseif Toggles.AntiTeleportRaknet.Value then
						Toggles.AntiTeleportRaknet:SetValue(false)
					end
					Services.RunService.RenderStepped:Wait()
					Toggles.AntiTeleport:SetDisabled(true)
					if not Toggles.AntiTeleportRaknet.Disabled then
						Toggles.AntiTeleportRaknet:SetDisabled(true)
					end
					Variables.tpFunction = getTpFunction()
					if hookfunction then
						if Variables.tpFunction then
							local tp; tp = hookfunction(Variables.tpFunction, function(...)
								if checkcaller() then
									tp(...)
								end
							end)
						end
						local hook; hook = hookfunction(ServerTeleported.OnClientEvent.Connect, function(self, func)
							if not checkcaller() then
								hookfunction(func, function()end)
								Variables.tpFunction = func
							end
							return hook(self, func)
						end)
					end
					local tempRoom = CurrentRooms:FindFirstChild(LatestRoom.Value)
					Variables.AutoFloorRoom = Library:Notify({
						Title = Info.AddonTitle,
						Description = `Doors opened: {LatestRoom.Value}\nCurrent room: {tempRoom and tempRoom:GetAttribute("RawName") or "?"}`,
						Persist = true
					})
					local AutoFloor = {}
					Connections.AutoFloor = AutoFloor
					local key, drawer
					AutoFloor.Teleporter = Services.RunService.Heartbeat:Connect(function()
                        if MrHShouldPauseAutoFloor() then return end
						local Room = CurrentRooms:FindFirstChild(LatestRoom.Value)
						local Door = Room and Room:FindFirstChild("Door")
						if not Variables.slideSH then
							Variables.slideSH = true
							Crouch:FireServer(true,true)
						end
						for _, toggle in Variables.StuffToKeepEnabled do
							if not toggle.Value and not toggle.Disabled then
								toggle:SetValue(true)
							end
						end
						local item = ItemThatCanUnlock()
						if item then
							if not Variables.InfItems.Value then
								Variables.InfItems:SetValue(true)
							end
							if item:IsA("Tool") and item.Parent ~= Character then
								item.Parent = Character
							elseif item:IsA("Model") then
								item:PivotTo(Character:GetPivot())
								fireproximityprompt(item.ModulePrompt)
							end
							MrHAutoFloorPivot(Door:GetPivot())
							local prompt = Door.Lock:FindFirstChild("UnlockPrompt") or Door.Lock:FindFirstChild("FakePrompt")
							if prompt then
								fireproximityprompt(prompt)
							end
						else
							local tool = GetEquippedTool(LocalPlayer)
							if LocalPlayer.Backpack:FindFirstChild("Key") or (tool and tool.Name == "Key") then
								key = nil
								drawer = nil
								MrHAutoFloorPivot(Door:GetPivot())
								local prompt = Door.Lock:FindFirstChild("UnlockPrompt") or Door.Lock:FindFirstChild("FakePrompt")
								if prompt then
									fireproximityprompt(prompt)
								end
							else
								if not key or not drawer then
									key, drawer = FindKeyObtain(Room)
								end
								if key then
									MrHAutoFloorPivot(drawer and drawer:GetPivot() or key:GetPivot())
									if drawer then
										fireproximityprompt(drawer.Knobs.ActivateEventPrompt)
									end
									fireproximityprompt(key.ModulePrompt)
								else
									Library:Notify({
										Title = Info.AddonTitle,
										Description = "Endless completed!",
										Time = 10
									})
									Toggles.AutoFloor:SetValue(false)
									Toggles.AutoFloor:SetDisabled(true)
								end
							end
						end
					end)
					AutoFloor.LatestRoomChanged = LatestRoom.Changed:Connect(function()
						room = CurrentRooms:FindFirstChild(LatestRoom.Value)
						if Variables.AutoFloorRoom then
							Variables.AutoFloorRoom:ChangeDescription(`Doors opened: {LatestRoom.Value}\nCurrent room: {room and room:GetAttribute("RawName") or "?"}`)
						end
					end)
				else
					if Variables.AutoFloorRoom then
						Variables.AutoFloorRoom:Destroy()
					end
					Toggles.AntiTeleport:SetDisabled(false)
					if Variables.raknet_at_hook then
						Toggles.AntiTeleportRaknet:SetDisabled(false)
					end
					if isfunctionhooked and restorefunction then
						if Variables.tpFunction and isfunctionhooked(Variables.tpFunction) then
							restorefunction(Variables.tpFunction)
						end
						if isfunctionhooked(ServerTeleported.OnClientEvent.Connect) then
							restorefunction(ServerTeleported.OnClientEvent.Connect)
						end
					end
					if Connections.AutoFloor then
						for _, connection in Connections.AutoFloor do
							connection:Disconnect()
						end
						Connections.AutoFloor = nil
					end
				end
			end
		},
		Ripple_Daily_Default = {
			Requirements = {
				"fireproximityprompt",
				"hookfunction",
				"restorefunction",
				"isfunctionhooked"
			},
			Callback = function(value)
				if value then
					if Toggles.AntiTeleport.Value then
						Toggles.AntiTeleport:SetValue(false)
					elseif Toggles.AntiTeleportRaknet.Value then
						Toggles.AntiTeleportRaknet:SetValue(false)
					end
					Services.RunService.RenderStepped:Wait()
					Toggles.AntiTeleport:SetDisabled(true)
					if not Toggles.AntiTeleportRaknet.Disabled then
						Toggles.AntiTeleportRaknet:SetDisabled(true)
					end
					Variables.tpFunction = getTpFunction()
					if hookfunction then
						if Variables.tpFunction then
							local tp; tp = hookfunction(Variables.tpFunction, function(...)
								if checkcaller() then
									tp(...)
								end
							end)
						end
						local hook; hook = hookfunction(ServerTeleported.OnClientEvent.Connect, function(self, func)
							if not checkcaller() then
								hookfunction(func, function()end)
								Variables.tpFunction = func
							end
							return hook(self, func)
						end)
					end
					local tempRoom = CurrentRooms:FindFirstChild(LatestRoom.Value)
					Variables.AutoFloorRoom = Library:Notify({
						Title = Info.AddonTitle,
						Description = `Doors opened: {LatestRoom.Value}\nCurrent room: {tempRoom and tempRoom:GetAttribute("RawName") or "?"}\nAnticheat bypass status: {Character:GetAttribute("_BypassedAC") and "ON" or "OFF"}`,
						Persist = true
					})
					local AutoFloor = {}
					local activeRusher = ActiveRusher()
					Connections.AutoFloor = AutoFloor
					local key, drawer, fuse, buttonPressed, leverActivated, noGeneratorSince, buggyRun
					AutoFloor.Teleporter = Services.RunService.Heartbeat:Connect(function()
                        if MrHShouldPauseAutoFloor() then return end
						if buggyRun then return end
						activeRusher = ActiveRusher()
						local Room = CurrentRooms:FindFirstChild(LatestRoom.Value)
						local Door = Room and Room:FindFirstChild("Door")
						if not Variables.slideSH then
							Variables.slideSH = true
							Crouch:FireServer(true,true)
						end
						for _, toggle in Variables.StuffToKeepEnabled do
							if not toggle.Value and not toggle.Disabled then
								toggle:SetValue(true)
							end
						end
						local grabPart = not Character:GetAttribute("_BypassedAC") and GetNearestLadderGrabPart(Room)
						if activeRusher then
							if Library.Toggles.DoorReach.Value then
								Library.Toggles.DoorReach:SetValue(false)
							end
							return
						elseif Character:GetAttribute("Climbing") then
							Character:SetAttribute("Climbing")
							Character:SetAttribute("_BypassedAC", true)
							Connections.OnBypassRemove = Character:GetAttributeChangedSignal("Climbing"):Once(function()
								Character:SetAttribute("_BypassedAC", false)
								if Variables.AutoFloorRoom then
									Variables.AutoFloorRoom:ChangeDescription(`Doors opened: {LatestRoom.Value}\nCurrent room: {Room and Room:GetAttribute("RawName") or "?"}\nAnticheat bypass status: {Character:GetAttribute("_BypassedAC") and "ON" or "OFF"}`)
								end
							end)
							if Variables.AutoFloorRoom then
								Variables.AutoFloorRoom:ChangeDescription(`Doors opened: {LatestRoom.Value}\nCurrent room: {Room and Room:GetAttribute("RawName") or "?"}\nAnticheat bypass status: {Character:GetAttribute("_BypassedAC") and "ON" or "OFF"}`)
							end
						elseif grabPart then
							MrHAutoFloorPivot(grabPart.CFrame)
							fireproximityprompt(grabPart.ClimbPrompt)
						elseif Room:GetAttribute("RequiresKey") then
							local item = ItemThatCanUnlock()
							if item then
								if not Variables.InfItems.Value then
									Variables.InfItems:SetValue(true)
								end
								if item:IsA("Tool") and item.Parent ~= Character then
									item.Parent = Character
								elseif item:IsA("Model") then
									item:PivotTo(Character:GetPivot())
									fireproximityprompt(item.ModulePrompt)
								end
								MrHAutoFloorPivot(Door:GetPivot())
								local prompt = Door.Lock:FindFirstChild("UnlockPrompt") or Door.Lock:FindFirstChild("FakePrompt")
								if prompt then
									fireproximityprompt(prompt)
								end
							else
								local tool = GetEquippedTool(LocalPlayer)
								local keyTool = LocalPlayer.Backpack:FindFirstChild("Key") or (tool and tool.Name == "Key" and tool) or LocalPlayer.Backpack:FindFirstChild("KeyBackdoor") or (tool and tool.Name == "KeyBackdoor" and tool)
								if keyTool then
									key = nil
									drawer = nil
									if keyTool.Name == "KeyBackdoor" and keyTool.Parent ~= Character then
										keyTool.Parent = Character
									end
									MrHAutoFloorPivot(Door:GetPivot())
									local prompt = Door.Lock:FindFirstChild("UnlockPrompt") or Door.Lock:FindFirstChild("FakePrompt")
									if prompt then
										fireproximityprompt(prompt)
									end
								else
									if not key or not drawer then
										key, drawer = FindKeyObtain(Room)
									end
									if key then
										MrHAutoFloorPivot(drawer and drawer:GetPivot() or key:GetPivot())
										if drawer then
											fireproximityprompt(drawer:FindFirstChild("ActivateEventPrompt", true))
										end
										fireproximityprompt(key.ModulePrompt)
									end
								end
							end
						elseif Room:GetAttribute("RequiresGenerator") then
							local fuse = GetNearestFuse(Room)
							if fuse then
								MrHAutoFloorPivot(fuse:GetPivot())
								local openFirst = fuse:FindFirstAncestor("Locker_Small") or fuse:FindFirstAncestor("DrawerContainer") or fuse:FindFirstAncestor("Toolbox")
								if openFirst then
									fireproximityprompt(openFirst:FindFirstChild("ActivateEventPrompt", true))
								end
								fireproximityprompt(fuse.ModulePrompt)
							else
								local gen = Room.Assets:FindFirstChild("MinesGenerator")
								if gen then
									noGeneratorSince = nil
								else
									noGeneratorSince = noGeneratorSince or os.clock()
									if noGeneratorSince < os.clock()-3 then
										buggyRun = true
										Library:Notify({
											Title = Info.AddonTitle,
											Description = "Generation bug detected: MinesGenerator didn't spawn in the room that requires generator\n(The game will be automatically restarted)",
											Persist = true
										})
										PlayAgain:FireServer()
									end
									return
								end
								local notTuff = false
								for _, fuse in gen.Fuses:GetChildren() do
									if tonumber(fuse.Name) and fuse.Fuse.Transparency == 1 then
										notTuff = true
										break
									end
								end
								local prompt = notTuff and (gen:FindFirstChild("FusesPrompt", true) or gen:FindFirstChild("FakePrompt", true))
								if prompt then
									MrHAutoFloorPivot(gen:GetPivot())
									fireproximityprompt(prompt)
								elseif not leverActivated then
									prompt = gen.Lever.LeverPrompt
									MrHAutoFloorPivot(gen:GetPivot())
									fireproximityprompt(prompt)
									if gen.GeneratorMain.Sound.Playing then
										leverActivated = true
									end
								elseif not buttonPressed then
									local button = Room.Assets.MinesGateButton.Button
									prompt = button.ActivateEventPrompt
									MrHAutoFloorPivot(button.CFrame)
									fireproximityprompt(prompt)
									if button.SoundPress.Playing then
										buttonPressed = true
									end
								else
									MrHAutoFloorPivot(Door:GetPivot())
								end
							end
						elseif Room:GetAttribute("RawName") == "RippleEnd" then
							if not AutoFloor.OnStatistics then
								AutoFloor.OnStatistics = RippleStatistics.OnClientEvent:Connect(function()
									Library:Notify({
										Title = Info.AddonTitle,
										Description = "Daily run completed!",
										Time = 10
									})
									Toggles.AutoFloor:SetValue(false)
									Toggles.AutoFloor:SetDisabled(true)
								end)
							end
							Door = Room.RippleExitDoor
							MrHAutoFloorPivot(Door:GetPivot())
							fireproximityprompt(Door.Door.EnterPrompt)
						else
							MrHAutoFloorPivot(Door:GetPivot())
						end
						if not Library.Toggles.DoorReach.Value then
							Library.Toggles.DoorReach:SetValue(true)
						end
					end)
					AutoFloor.LatestRoomChanged = LatestRoom.Changed:Connect(function()
						leverActivated = nil
						buttonPressed = nil
						room = CurrentRooms:FindFirstChild(LatestRoom.Value)
						if Variables.AutoFloorRoom then
							Variables.AutoFloorRoom:ChangeDescription(`Doors opened: {LatestRoom.Value}\nCurrent room: {room and room:GetAttribute("RawName") or "?"}\nAnticheat bypass status: {Character:GetAttribute("_BypassedAC") and "ON" or "OFF"}`)
						end
					end)
				else
					if Variables.AutoFloorRoom then
						Variables.AutoFloorRoom:Destroy()
					end
					Toggles.AntiTeleport:SetDisabled(false)
					if Variables.raknet_at_hook then
						Toggles.AntiTeleportRaknet:SetDisabled(false)
					end
					if isfunctionhooked and restorefunction then
						if Variables.tpFunction and isfunctionhooked(Variables.tpFunction) then
							restorefunction(Variables.tpFunction)
						end
						if isfunctionhooked(ServerTeleported.OnClientEvent.Connect) then
							restorefunction(ServerTeleported.OnClientEvent.Connect)
						end
					end
					if Connections.AutoFloor then
						for _, connection in Connections.AutoFloor do
							connection:Disconnect()
						end
						Connections.AutoFloor = nil
					end
				end
			end
		},
		Garden = {
			Requirements = {
				"firetouchinterest",
				"fireproximityprompt",
				"hookfunction",
				"restorefunction",
				"isfunctionhooked"
			},
			Callback = function(value)
				if value then
					if Toggles.AntiTeleport.Value then
						Toggles.AntiTeleport:SetValue(false)
					elseif Toggles.AntiTeleportRaknet.Value then
						Toggles.AntiTeleportRaknet:SetValue(false)
					end
					Services.RunService.RenderStepped:Wait()
					Toggles.AntiTeleport:SetDisabled(true)
					if not Toggles.AntiTeleportRaknet.Disabled then
						Toggles.AntiTeleportRaknet:SetDisabled(true)
					end
					Variables.tpFunction = getTpFunction()
					if Variables.tpFunction then
						local tp; tp = hookfunction(Variables.tpFunction, function(...)
							if checkcaller() then
								tp(...)
							end
						end)
					end
					local hook; hook = hookfunction(ServerTeleported.OnClientEvent.Connect, function(self, func)
						if not checkcaller() then
							hookfunction(func, function()end)
							Variables.tpFunction = func
						end
						return hook(self, func)
					end)
					local tempRoom = CurrentRooms:FindFirstChild(LatestRoom.Value)
					Variables.AutoFloorRoom = Library:Notify({
						Title = Info.AddonTitle,
						Description = `Doors opened: {LatestRoom.Value}\nCurrent room: {tempRoom and tempRoom:GetAttribute("RawName") or "?"}`,
						Persist = true
					})
					local AutoFloor = {}
					Connections.AutoFloor = AutoFloor
					local unavailableUntil = -1/0
					local lastCutscene = ""
					local LOTUS, PICKING_LOTUS = false, false
					AutoFloor.Teleporter = Services.RunService.Heartbeat:Connect(function()
                        if MrHShouldPauseAutoFloor() then return end
						logprint("WORKS")
						local Room = CurrentRooms:FindFirstChild(LatestRoom.Value)
						local Door = Room and Room:FindFirstChild("Door")
						local eyestalkEnd = Room:GetAttribute("RawName") == "Garden_EyestalkEnd" and Toggles.TriggerEyestalkChaseEnd.Value and (lastCutscene ~= "EyestalkOutro" or Character.PrimaryPart.Anchored)
						if os.clock()<unavailableUntil or (eyestalkEnd and Character.PrimaryPart.Anchored) then logprint("RETURNED", os.clock()<unavailableUntil, (eyestalkEnd and Character.PrimaryPart.Anchored))  return end
						if not Variables.slideSH then
							Variables.slideSH = true
							Crouch:FireServer(true,true)
						end
						for _, toggle in Variables.StuffToKeepEnabled do
							if not toggle.Value and not toggle.Disabled then
								toggle:SetValue(true)
							end
						end
						local lotuspetal, drawer, grampy
						local tool = GetEquippedTool(LocalPlayer)
						if Toggles.MakeLotus.Value and not (LocalPlayer.Backpack:FindFirstChild("Lotus") or (tool and tool.Name == "Lotus")) then
							lotuspetal, drawer = GetLotusPetal()
							grampy = CurrentRooms:FindFirstChild("Grampy", true)
							grampy = grampy and (tonumber(grampy.Parent.Parent.Name) or 0) <= LatestRoom.Value and grampy
						end
						local lotuspetaltool = (tool and tool.Name == "LotusPetal" and tool) or LocalPlayer.Backpack:FindFirstChild("LotusPetal")
						local success, forminglotus = pcall(function()
							return Room.Assets.FormingLotus
						end)
						forminglotus = success and forminglotus
						if grampy and not LOTUS and lotuspetaltool and lotuspetaltool:GetAttribute("Durability") > 7 then
							logprint(1)
							PICKING_LOTUS = true
							MrHAutoFloorPivot(grampy:GetPivot())
							if lotuspetaltool.Parent ~= Character then
								lotuspetaltool.Parent = Character
							end
							fireproximityprompt(grampy.DialogPrompt)
						elseif grampy and not LOTUS and PICKING_LOTUS then
							if tool and tool.Name == "Lotus" then
								logprint(2.1)
								LOTUS = true
							elseif forminglotus and forminglotus:FindFirstChild("Lotus") then
								logprint(2.2)
								MrHAutoFloorPivot(forminglotus:GetPivot())
								fireproximityprompt(forminglotus.Lotus.PromptAttach.ModulePrompt)
							end
						elseif lotuspetal and not (lotuspetaltool and lotuspetaltool:GetAttribute("Durability") > 7) then
							logprint(3)
							MrHAutoFloorPivot(lotuspetal:GetPivot())
							if drawer then
								fireproximityprompt(drawer:FindFirstChild("ActivateEventPrompt", true))
							end
							fireproximityprompt(lotuspetal.ModulePrompt)
						elseif eyestalkEnd then
							if not AutoFloor.CutsceneActivated then
								AutoFloor.CutsceneActivated = Cutscene.OnClientEvent:Connect(function(name)
									lastCutscene = name
								end)
							end
							if lastCutscene == "EyestalkOutro" then
								logprint(4.1)
								AutoFloor.CutsceneActivated:Disconnect()
							else
								logprint(4.2)
								MrHAutoFloorPivot(Room.EyestalkEndCutscene.Collision.CFrame)
								firetouchinterest(Character.PrimaryPart, Room.EyestalkEndCutscene.Collision, 0)
								firetouchinterest(Character.PrimaryPart, Room.EyestalkEndCutscene.Collision, 1)
							end
						elseif Room.Name == "35" then
							if not AutoFloor.CutsceneActivated then
								AutoFloor.CutsceneActivated = Cutscene.OnClientEvent:Connect(function(name)
									lastCutscene = name
								end)
							end
							if lastCutscene == "BrambleIntro" then
								logprint(5.1)
								local Lever = GetNearestLever(Room)
								if Lever then
									logprint("5.1.1")
									MrHAutoFloorPivot(Lever.CFrame)
									fireproximityprompt(Lever.ActivateEventPrompt)
								else
									logprint("5.1.2")
									MrHAutoFloorPivot(Room.OutdoorsEnding.Collision.CFrame)
									firetouchinterest(Character.PrimaryPart, Room.OutdoorsEnding.Collision, 0)
									firetouchinterest(Character.PrimaryPart, Room.OutdoorsEnding.Collision, 1)
								end
							elseif lastCutscene == "EyestalkOutro" or lastCutscene == "" then
								logprint(5.2)
								MrHAutoFloorPivot(Room.BrambleCutscene.Collision.CFrame)
								firetouchinterest(Character.PrimaryPart, Room.BrambleCutscene.Collision, 0)
								firetouchinterest(Character.PrimaryPart, Room.BrambleCutscene.Collision, 1)
							else
								logprint(5.3)
								Library:Notify({
									Title = Info.AddonTitle,
									Description = "Outdoors completed!",
									Time = 10
								})
								Toggles.AutoFloor:SetValue(false)
								Toggles.AutoFloor:SetDisabled(true)
							end
						else
							logprint(6)
							MrHAutoFloorPivot(Door:GetPivot())
						end
						if not Library.Toggles.DoorReach.Value then
							Library.Toggles.DoorReach:SetValue(true)
						end
					end)
					AutoFloor.LatestRoomChanged = LatestRoom.Changed:Connect(function()
						room = CurrentRooms:FindFirstChild(LatestRoom.Value)
						if Variables.AutoFloorRoom then
							Variables.AutoFloorRoom:ChangeDescription(`Doors opened: {LatestRoom.Value}\nCurrent room: {room and room:GetAttribute("RawName") or "?"}`)
						end
						if Toggles.MakeLotus.Value then
							unavailableUntil = os.clock()+.5
						end
					end)
				else
					if Variables.AutoFloorRoom then
						Variables.AutoFloorRoom:Destroy()
					end
					Toggles.AntiTeleport:SetDisabled(false)
					if Variables.raknet_at_hook then
						Toggles.AntiTeleportRaknet:SetDisabled(false)
					end
					if Variables.tpFunction and isfunctionhooked(Variables.tpFunction) then
						restorefunction(Variables.tpFunction)
					end
					if isfunctionhooked(ServerTeleported.OnClientEvent.Connect) then
						restorefunction(ServerTeleported.OnClientEvent.Connect)
					end
					if Connections.AutoFloor then
						for _, connection in Connections.AutoFloor do
							connection:Disconnect()
						end
						Connections.AutoFloor = nil
					end
				end
			end
		},
		Backdoor = {
			Requirements = {
				"fireproximityprompt",
				"hookfunction",
				"restorefunction",
				"isfunctionhooked"
			},
			Callback = function(value)
				if value then
					if Toggles.AntiTeleport.Value then
						Toggles.AntiTeleport:SetValue(false)
					elseif Toggles.AntiTeleportRaknet.Value then
						Toggles.AntiTeleportRaknet:SetValue(false)
					end
					Services.RunService.RenderStepped:Wait()
					Toggles.AntiTeleport:SetDisabled(true)
					if not Toggles.AntiTeleportRaknet.Disabled then
						Toggles.AntiTeleportRaknet:SetDisabled(true)
					end
					Variables.tpFunction = getTpFunction()
					if hookfunction then
						if Variables.tpFunction then
							local tp; tp = hookfunction(Variables.tpFunction, function(...)
								if checkcaller() then
									tp(...)
								end
							end)
						end
						local hook; hook = hookfunction(ServerTeleported.OnClientEvent.Connect, function(self, func)
							if not checkcaller() then
								hookfunction(func, function()end)
								Variables.tpFunction = func
							end
							return hook(self, func)
						end)
					end
					local tempRoom = CurrentRooms:FindFirstChild(LatestRoom.Value)
					Variables.AutoFloorRoom = Library:Notify({
						Title = Info.AddonTitle,
						Description = `Doors opened: {LatestRoom.Value}\nCurrent room: {tempRoom and tempRoom:GetAttribute("RawName") or "?"}\nAnticheat bypass status: {Character:GetAttribute("_BypassedAC") and "ON" or "OFF"}`,
						Persist = true
					})
					local AutoFloor = {}
					Connections.AutoFloor = AutoFloor
					local unavailableUntil = -1/0
					local key, drawer, timerincreased
					AutoFloor.Teleporter = Services.RunService.Heartbeat:Connect(function()
                        if MrHShouldPauseAutoFloor() then return end
						if os.clock()<unavailableUntil then return end
						activeRusher = ActiveRusher()
						local Room = CurrentRooms:FindFirstChild(LatestRoom.Value)
						local Door = Room and Room:FindFirstChild("Door")
						if not Variables.slideSH then
							Variables.slideSH = true
							Crouch:FireServer(true,true)
						end
						for _, toggle in Variables.StuffToKeepEnabled do
							if not toggle.Value and not toggle.Disabled then
								toggle:SetValue(true)
							end
						end
						local timerlever = Room:FindFirstChild("TimerLever", true)
						if timerlever and not timerincreased then
							MrHAutoFloorPivot(timerlever:GetPivot())
							fireproximityprompt(timerlever.ActivateEventPrompt)
							if timerlever.TakeTimer.TextLabel.Text == "00:00" then
								timerincreased = true
							end
						elseif Room:GetAttribute("RequiresKey") then
							local item = ItemThatCanUnlock()
							if item then
								if not Variables.InfItems.Value then
									Variables.InfItems:SetValue(true)
								end
								if item:IsA("Tool") and item.Parent ~= Character then
									item.Parent = Character
								elseif item:IsA("Model") then
									item:PivotTo(Character:GetPivot())
									fireproximityprompt(item.ModulePrompt)
								end
								MrHAutoFloorPivot(Door:GetPivot())
								local prompt = Door.Lock:FindFirstChild("UnlockPrompt") or Door.Lock:FindFirstChild("FakePrompt")
								if prompt then
									fireproximityprompt(prompt)
								end
							else
								local tool = GetEquippedTool(LocalPlayer)
								local keyTool = LocalPlayer.Backpack:FindFirstChild("Key") or (tool and tool.Name == "Key" and tool) or LocalPlayer.Backpack:FindFirstChild("KeyBackdoor") or (tool and tool.Name == "KeyBackdoor" and tool)
								if keyTool then
									key = nil
									drawer = nil
									if keyTool.Name == "KeyBackdoor" and keyTool.Parent ~= Character then
										keyTool.Parent = Character
									end
									MrHAutoFloorPivot(Door:GetPivot())
									local prompt = Door.Lock:FindFirstChild("UnlockPrompt") or Door.Lock:FindFirstChild("FakePrompt")
									if prompt then
										fireproximityprompt(prompt)
									end
								else
									if not key or not drawer then
										key, drawer = FindKeyObtain(Room)
									end
									if key then
										MrHAutoFloorPivot(drawer and drawer:GetPivot() or key:GetPivot())
										if drawer then
											fireproximityprompt(drawer:FindFirstChild("ActivateEventPrompt", true))
										end
										fireproximityprompt(key.ModulePrompt)
									end
								end
							end
						elseif Room.Name == "50" then
							if not AutoFloor.OnStatistics then
								AutoFloor.OnStatistics = Statistics.OnClientEvent:Connect(function()
									Library:Notify({
										Title = Info.AddonTitle,
										Description = "Backdoor completed!",
										Time = 10
									})
									Toggles.AutoFloor:SetValue(false)
									Toggles.AutoFloor:SetDisabled(true)
								end)
							end
							Door = Room.Backdoors_Exit.Door
							MrHAutoFloorPivot(Door:GetPivot())
							fireproximityprompt(Door.EnterPrompt)
						else
							MrHAutoFloorPivot(Door:GetPivot())
						end
						if not Library.Toggles.DoorReach.Value then
							Library.Toggles.DoorReach:SetValue(true)
						end
					end)
					AutoFloor.LatestRoomChanged = LatestRoom.Changed:Connect(function()
						timerincreased = nil
						room = CurrentRooms:FindFirstChild(LatestRoom.Value)
						if Variables.AutoFloorRoom then
							Variables.AutoFloorRoom:ChangeDescription(`Doors opened: {LatestRoom.Value}\nCurrent room: {room and room:GetAttribute("RawName") or "?"}\nAnticheat bypass status: {Character:GetAttribute("_BypassedAC") and "ON" or "OFF"}`)
						end
						unavailableUntil = os.clock()+1
					end)
				else
					if Variables.AutoFloorRoom then
						Variables.AutoFloorRoom:Destroy()
					end
					Toggles.AntiTeleport:SetDisabled(false)
					if Variables.raknet_at_hook then
						Toggles.AntiTeleportRaknet:SetDisabled(false)
					end
					if isfunctionhooked and restorefunction then
						if Variables.tpFunction and isfunctionhooked(Variables.tpFunction) then
							restorefunction(Variables.tpFunction)
						end
						if isfunctionhooked(ServerTeleported.OnClientEvent.Connect) then
							restorefunction(ServerTeleported.OnClientEvent.Connect)
						end
					end
					if Connections.AutoFloor then
						for _, connection in Connections.AutoFloor do
							connection:Disconnect()
						end
						Connections.AutoFloor = nil
					end
				end
			end
		},
		Stairwell = {
			Requirements = {
				"fireproximityprompt",
				"hookfunction",
				"restorefunction",
				"isfunctionhooked"
			},
			Callback = function(value)
				if value then
					if Toggles.AntiTeleport.Value then
						Toggles.AntiTeleport:SetValue(false)
					elseif Toggles.AntiTeleportRaknet.Value then
						Toggles.AntiTeleportRaknet:SetValue(false)
					end
					Services.RunService.RenderStepped:Wait()
					Toggles.AntiTeleport:SetDisabled(true)
					if not Toggles.AntiTeleportRaknet.Disabled then
						Toggles.AntiTeleportRaknet:SetDisabled(true)
					end
					Variables.tpFunction = getTpFunction()
					if hookfunction then
						if Variables.tpFunction then
							local tp; tp = hookfunction(Variables.tpFunction, function(...)
								if checkcaller() then
									tp(...)
								end
							end)
						end
						local hook; hook = hookfunction(ServerTeleported.OnClientEvent.Connect, function(self, func)
							if not checkcaller() then
								hookfunction(func, function()end)
								Variables.tpFunction = func
							end
							return hook(self, func)
						end)
					end
					local tempRoom = CurrentRooms:FindFirstChild(LatestRoom.Value)
					Variables.AutoFloorRoom = Library:Notify({
						Title = Info.AddonTitle,
						Description = `Doors opened: {LatestRoom.Value}\nCurrent room: {tempRoom and tempRoom:GetAttribute("RawName") or "?"}`,
						Persist = true
					})
					local AutoFloor = {}
					Connections.AutoFloor = AutoFloor
					AutoFloor.Teleporter = Services.RunService.Heartbeat:Connect(function()
                        if MrHShouldPauseAutoFloor() then return end
						local Room = CurrentRooms:FindFirstChild(LatestRoom.Value)
						local Door = Room and Room:FindFirstChild("Door")
						if not Variables.slideSH then
							Variables.slideSH = true
							Crouch:FireServer(true,true)
						end
						for _, toggle in Variables.StuffToKeepEnabled do
							if not toggle.Value and not toggle.Disabled then
								toggle:SetValue(true)
							end
						end
						if LatestRoom.Value > 198 then
							local stairwellexit = Room:FindFirstChild("StairwellExitDoor")
							if stairwellexit then
								MrHAutoFloorPivot(stairwellexit:GetPivot())
								fireproximityprompt(stairwellexit.Collision.EnterPrompt)
							else
								Library:Notify({
									Title = Info.AddonTitle,
									Description = "Stairwell completed!",
									Time = 10
								})
								Toggles.AutoFloor:SetValue(false)
								Toggles.AutoFloor:SetDisabled(true)
							end
						else
							MrHAutoFloorPivot(Door:GetPivot())
						end
						if not Library.Toggles.DoorReach.Value then
							Library.Toggles.DoorReach:SetValue(true)
						end
					end)
					AutoFloor.LatestRoomChanged = LatestRoom.Changed:Connect(function()
						if Variables.AutoFloorRoom then
							Variables.AutoFloorRoom:ChangeDescription(`Doors opened: {LatestRoom.Value}\nCurrent room: {room and room:GetAttribute("RawName") or "?"}`)
						end
					end)
				else
					if Variables.AutoFloorRoom then
						Variables.AutoFloorRoom:Destroy()
					end
					if not Toggles.SlideSpeedHack and Variables.slideSH then
						Variables.slideSH = false
						Crouch:FireServer(true,true)
					end
					Toggles.AntiTeleport:SetDisabled(false)
					if Variables.raknet_at_hook then
						Toggles.AntiTeleportRaknet:SetDisabled(false)
					end
					if isfunctionhooked and restorefunction then
						if Variables.tpFunction and isfunctionhooked(Variables.tpFunction) then
							restorefunction(Variables.tpFunction)
						end
						if isfunctionhooked(ServerTeleported.OnClientEvent.Connect) then
							restorefunction(ServerTeleported.OnClientEvent.Connect)
						end
					end
					if Connections.AutoFloor then
						for _, connection in Connections.AutoFloor do
							connection:Disconnect()
						end
						Connections.AutoFloor = nil
					end
				end
			end
		},
	}

	function ExecutorSupported(AutoFloor)
		for _, funcName in AutoFloor.Requirements do
			if not (getgenv and getgenv()[funcName]) then
				return false
			end
		end
		return true
	end

	Variables.AutoFloorFunc = Variables.AutoFloors[Floor] or Variables.AutoFloors[`{Floor}_{FloorSpecific}`]
	Variables.AutoFloorSupported = ExecutorSupported(Variables.AutoFloorFunc or {Requirements = {}})

    local mrhMovement = Floor=="Rooms" and "Pathfind" or "TP"
    local mrhActiveEngine = nil
    local function mrhCanRun()
        if mrhMovement=="Pathfind" or Floor=="Rooms" then return type(fireproximityprompt)=="function" end
        return Variables.AutoFloorSupported and Variables.AutoFloorFunc~=nil
    end
    local function mrhStopEngine()
        local previous=mrhActiveEngine
        mrhActiveEngine=nil
        mrhPathfindEngine.SetEnabled(false)
        if previous=="TP" and Variables.AutoFloorFunc then Variables.AutoFloorFunc.Callback(false) end
        mrhReleasePause()
    end
    local function mrhRunEngine(value)
        mrhStopEngine()
        if not value then return end
        if not mrhCanRun() then
            Library:Notify({Title="Auto Floor",Description="Selected method is unavailable on this floor or executor.",Time=5})
            if Toggles.AutoFloor then Toggles.AutoFloor:SetValue(false) end
            return
        end
        if mrhMovement=="Pathfind" or Floor=="Rooms" then
            -- Avoid competing WalkSpeed and drawer-position controllers.
            for _,toggle in pairs({Toggles.SlideSpeedHack,Toggles.RakNetSpeedHack,Variables.SpeedHack,Toggles.BringDrawers}) do
                if toggle and toggle.Value then toggle:SetValue(false) end
            end
            mrhActiveEngine="Pathfind"
            mrhPathfindEngine.SetEnabled(true,mrhMovement)
        else
            mrhActiveEngine="TP"
            Variables.AutoFloorFunc.Callback(true)
        end
    end
    Groupbox:AddDropdown(prefix.."AutoFloorMovement", {
        Text="Auto Floor Movement",Values={"TP","Pathfind"},Default=mrhMovement,Multi=false,
        Tooltip="TP: tplay floor solver. Pathfind: walk at speed 40 with priority hiding, loot and camera settings. Special floor puzzles may require manual completion. Rooms supports both methods through the imported engine.",
        Callback=function(value)
            if value==mrhMovement then return end
            local resume=Toggles.AutoFloor and Toggles.AutoFloor.Value
            mrhStopEngine()
            mrhMovement=value
            if Toggles.AutoFloor then
                Toggles.AutoFloor:SetDisabled(not mrhCanRun())
                if resume then
                    if mrhCanRun() then mrhRunEngine(true) else Toggles.AutoFloor:SetValue(false) end
                end
            end
        end,
    })
    Toggles.AutoFloor=Groupbox:AddToggle(prefix.."AutoFloor", {
        Text="Auto Floor",Default=false,Disabled=not mrhCanRun(),
        DisabledTooltip="Choose Pathfind or use a supported TP floor/executor.",
        Callback=mrhRunEngine,
    })
    Groupbox:AddLabel("Pathfind / Rooms controls: Auto Floor Settings tab. Normal/Safe/Rush applies to tplay TP; the imported engine always puts hiding first.",true)
    OnUnload(mrhStopEngine)

	if Floor == "Garden" then
		local cutscenes = {}
		Connections.OnCutsceneSEC = Cutscene.OnClientEvent:Connect(function(name)
			if not table.find(cutscenes, name) then
				table.insert(cutscenes, name)
			end
		end)

		Toggles.SkipEyestalkChase = Groupbox:AddToggle(prefix.."SkipEyestalkChase", {
			Text = "Skip Eyestalk Chase [FE]",
			DisabledTooltip = Variables.AutoFloorSupported and "Eyestalk chase was skipped" or "Executor is not supported",
			Default = false,
			Disabled = not Variables.AutoFloorSupported,

			Callback = function(value)
				if value then
					Connections.SECConnection = Services.RunService.RenderStepped:Connect(function()
						if table.find(cutscenes, "EyestalkOutro") then
							if Toggles.AutoFloor.Value then
								Toggles.AutoFloor:SetValue(false)
							end
							if Toggles.TriggerEyestalkChaseEnd.Value then
								Toggles.TriggerEyestalkChaseEnd:SetValue(true)
							end
							Toggles.SkipEyestalkChase:SetValue(false)
							Toggles.SkipEyestalkChase:SetDisabled(true)
						elseif table.find(cutscenes, "EyestalkIntro") then
							if not Toggles.TriggerEyestalkChaseEnd.Value then
								Toggles.TriggerEyestalkChaseEnd:SetValue(true)
							end
							if not Toggles.AutoFloor.Value then
								Toggles.AutoFloor:SetValue(true)
							end
						end
					end)
				else
					if Connections.SECConnection then
						Connections.SECConnection:Disconnect()
					end
					if Toggles.AutoFloor.Value then
						Toggles.AutoFloor:SetValue(false)
					end
				end
			end
		})

		Toggles.TriggerEyestalkChaseEnd = Groupbox:AddToggle(prefix.."TriggerEyestalkChaseEnd", {
			Text = "Trigger Eyestalk Chase End",
			Tooltip = "Don't skip trigger that ends Eyestalk Chase while Auto Floor enabled",
			DisabledTooltip = "Executor is not supported",
			Default = false,
			Disabled = not Variables.AutoFloorSupported
		})

		Toggles.MakeLotus = Groupbox:AddToggle(prefix.."MakeLotus", {
			Text = "Make Lotus",
			Tooltip = "Should Auto Floor collect Lotus Petals to make Lotus",
			DisabledTooltip = "Executor is not supported",
			Default = false,
			Disabled = not Variables.AutoFloorSupported
		})
	end

	function CustomContinueOrSave()
		task.defer(function()
			RequestLocalAsset:InvokeServer({{}})
			PlayAgain:FireServer()
		end)
		return true, nil
	end

	Variables.OldContinueOrSave = getcallbackvalue and getcallbackvalue(ContinueOrSave, "OnClientInvoke") or CustomContinueOrSave
	Variables.ContinueOrSaveHook = hookmetamethod and hookmetamethod(game, "__newindex", function(self, key, value)
		if not checkcaller() and self == ContinueOrSave and key == "OnClientInvoke" then
			Variables.OldContinueOrSave = value
			if Toggles.AutoPlayAgain.Value then
				value = CustomContinueOrSave
			end
		end
		return Variables.ContinueOrSaveHook(self, key, value)
	end)

	Toggles.AutoPlayAgain = Groupbox:AddToggle(prefix.."AutoPlayAgain", {
		Text = "Auto Play Again",
		Tooltip = "Works better with Fast Ending enabled",
		DisabledTooltip = "Executor is not supported",
		Default = false,
		Disabled = not Variables.ContinueOrSaveHook,

		Callback = function(value)
			if value then
				ContinueOrSave.OnClientInvoke = CustomContinueOrSave
				Connections.OnStatistics = Statistics.OnClientEvent:Connect(function()
					task.delay(.01, PlayAgain.FireServer, PlayAgain)
				end)
			else
				ContinueOrSave.OnClientInvoke = Variables.OldContinueOrSave
				if Connections.OnStatistics then
					Connections.OnStatistics:Disconnect()
				end
			end
		end
	})

	function clearEverything(list: {})
		list = typeof(list) == "table" and list or {}
		for _, val in list do
			if typeof(val) == "table" then
				clearEverything(val)
			elseif typeof(val) == "RBXScriptConnection" then
				pcall(val.Disconnect, val)
			elseif typeof(val) == "Instance" then
				pcall(val.Destroy, val)
			end
			val = nil
		end
	end

	OnUnload(function(wasReloaded)
		for _, toggle in Toggles do
			if toggle.Value then
				pcall(toggle.Callback, false)
			end
		end
		if deathHintConnection then
			deathHintConnection:Disconnect()
			deathHintConnection = nil
		end
		clearEverything(Connections)
		clearEverything(StuffToRemoveLater)
		GlobalIgnoreList = nil
		ScreenGui:Destroy()
		restoremetamethods()
		if Variables.ACBypassNotify then
			Variables.ACBypassNotify:Destroy()
			Variables.ACBypassNotify = nil
		end
		if Variables.admin then
			task.spawn(function()
				clearEverything(ItemsFromAddon)
				Variables.admin.AdminPanel.PanelClient.Enabled = false
				Variables.admin.Container.Pages:ClearAllChildren()
				local lol = Variables.admin.Container.TabButtons.UIListLayout:Clone()
				Variables.admin.Container.TabButtons:ClearAllChildren()
				lol.Parent = Variables.admin.Container.TabButtons
				Variables.admin.AdminPanel.PanelClient.Enabled = true
				Variables.admin = nil
			end)
		end
		print(`[{Info.AddonTitle}]: {wasReloaded and "reloaded" or "unloaded"}!`)
	end)
end

loaded = true

-- Local minigame; no game remotes or world changes.
do
    local snakeEnvironment = getgenv()
    if snakeEnvironment._MRH_SNAKE_CLEANUP then
        snakeEnvironment._MRH_SNAKE_CLEANUP()
    end
    -- Remove the old title left behind by an earlier addon reload.
    for _, name in ipairs({"Bullshit", "Snake"}) do
        local previousTab = Library.Tabs[name]
        if previousTab and not previousTab.Destroyed then
            previousTab:Destroy()
        end
    end
    local tab = Window:AddTab("Snake", "gamepad-2")
    local box = tab:AddLeftGroupbox("Snake")
    local controls = tab:AddRightGroupbox("Controls")
    local scoreLabel = box:AddLabel("Score: 0 | Best: 0")
    local statusLabel = controls:AddLabel("Press Start / Restart to play.", true)
    controls:AddLabel("WASD or arrow keys. Space pauses.\nYou can also use the direction buttons.\nLeaving this tab pauses the game.", true)
    local board = Instance.new("Frame")
    board.Name="MrHSnakeBoard"
    board.Size=UDim2.new(1,0,0,256)
    board.BackgroundColor3=Color3.fromRGB(15,20,25)
    board.BorderSizePixel=0
    board.ClipsDescendants=true
    board.Parent=box.Container
    local cells={}
    local N=16
    for y=1,N do
        cells[y]={}
        for x=1,N do
            local cell=Instance.new("Frame")
            cell.Size=UDim2.new(1/N,-1,1/N,-1)
            cell.Position=UDim2.fromScale((x-1)/N,(y-1)/N)
            cell.BackgroundColor3=Color3.fromRGB(24,31,38)
            cell.BorderSizePixel=0
            cell.Parent=board
            cells[y][x]=cell
        end
    end
    if box.Resize then box:Resize() end
    local snake, food, direction, pending = {}, nil, {x=1,y=0}, nil
    local score,best,elapsed=0,0,0
    local running,alive,disposed=false,false,false
    local input=Services.UserInputService
    local actions=Services.ContextActionService
    local actionName="MrHAddonSnakeInput"
    local function visible()
        local object=board
        while object do
            if object:IsA("GuiObject") and not object.Visible then return false end
            if object:IsA("ScreenGui") and not object.Enabled then return false end
            object=object.Parent
        end
        return board.Parent~=nil
    end
    local function draw()
        for y=1,N do for x=1,N do
            cells[y][x].BackgroundColor3=Color3.fromRGB(24,31,38)
        end end
        if food then cells[food.y][food.x].BackgroundColor3=Color3.fromRGB(255,100,100) end
        for i,point in ipairs(snake) do
            cells[point.y][point.x].BackgroundColor3=i==1 and Color3.fromRGB(220,255,130) or Color3.fromRGB(90,210,110)
        end
        scoreLabel:SetText("Score: "..score.." | Best: "..best)
    end
    local function spawnFood()
        local occupied={}
        for _,point in ipairs(snake) do occupied[(point.y-1)*N+point.x]=true end
        local free={}
        for y=1,N do for x=1,N do
            if not occupied[(y-1)*N+x] then free[#free+1]={x=x,y=y} end
        end end
        if #free==0 then
            food=nil running=false alive=false
            statusLabel:SetText("You won! Press Start / Restart.")
        else food=free[math.random(#free)] end
    end
    local function turn(x,y)
        if not running or pending then return end
        if x==-direction.x and y==-direction.y then return end
        pending={x=x,y=y}
    end
    local function pause()
        if not alive then return end
        running=not running elapsed=0
        statusLabel:SetText(running and "Playing" or "Paused — press Resume or Space.")
    end
    local function start()
        snake={{x=8,y=8},{x=7,y=8},{x=6,y=8}}
        direction={x=1,y=0} pending=nil
        score=0 elapsed=0 running=true alive=true
        spawnFood() draw() statusLabel:SetText("Playing")
    end
    local function step()
        direction=pending or direction pending=nil
        local head={x=snake[1].x+direction.x,y=snake[1].y+direction.y}
        local eating=food and head.x==food.x and head.y==food.y
        local collision=head.x<1 or head.x>N or head.y<1 or head.y>N
        -- The tail cell is free on a non-growing step.
        for i=1,#snake-(eating and 0 or 1) do
            if snake[i].x==head.x and snake[i].y==head.y then collision=true end
        end
        if collision then
            running=false alive=false
            statusLabel:SetText("Game over! Press Start / Restart.")
            return
        end
        table.insert(snake,1,head)
        if eating then score=score+1 best=math.max(best,score) spawnFood()
        else table.remove(snake) end
        draw()
    end
    controls:AddButton({Text="Start / Restart",Func=start})
    controls:AddButton({Text="Pause / Resume",Func=pause})
    controls:AddButton({Text="Up",Func=function() turn(0,-1) end})
    controls:AddButton({Text="Left",Func=function() turn(-1,0) end})
    controls:AddButton({Text="Down",Func=function() turn(0,1) end})
    controls:AddButton({Text="Right",Func=function() turn(1,0) end})
    local keys={
        [Enum.KeyCode.W]={0,-1}, [Enum.KeyCode.Up]={0,-1},
        [Enum.KeyCode.S]={0,1}, [Enum.KeyCode.Down]={0,1},
        [Enum.KeyCode.A]={-1,0}, [Enum.KeyCode.Left]={-1,0},
        [Enum.KeyCode.D]={1,0}, [Enum.KeyCode.Right]={1,0},
    }
    actions:BindActionAtPriority(actionName,function(_,state,event)
        if disposed or not visible() or input:GetFocusedTextBox() or not alive then
            return Enum.ContextActionResult.Pass
        end
        if event.KeyCode==Enum.KeyCode.Space then
            if state==Enum.UserInputState.Begin then pause() end
            return Enum.ContextActionResult.Sink
        end
        if not running then return Enum.ContextActionResult.Pass end
        if state==Enum.UserInputState.Begin then
            local move=keys[event.KeyCode]
            if move then turn(move[1],move[2]) end
        end
        return Enum.ContextActionResult.Sink
    end,false,3000,Enum.KeyCode.W,Enum.KeyCode.A,Enum.KeyCode.S,Enum.KeyCode.D,
        Enum.KeyCode.Up,Enum.KeyCode.Down,Enum.KeyCode.Left,Enum.KeyCode.Right,Enum.KeyCode.Space)
    local heartbeat=Services.RunService.Heartbeat:Connect(function(dt)
        if not running then return end
        if not visible() then running=false elapsed=0 statusLabel:SetText("Paused — press Resume.") return end
        elapsed=elapsed+dt
        if elapsed>=0.14 then elapsed=0 step() end
    end)
    local function cleanupSnake()
        if disposed then return end
        disposed=true running=false
        heartbeat:Disconnect()
        actions:UnbindAction(actionName)
        if not tab.Destroyed then tab:Destroy() end
        if snakeEnvironment._MRH_SNAKE_CLEANUP == cleanupSnake then
            snakeEnvironment._MRH_SNAKE_CLEANUP = nil
        end
    end
    snakeEnvironment._MRH_SNAKE_CLEANUP = cleanupSnake
    OnUnload(cleanupSnake)
end
