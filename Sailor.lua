local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")

-- Define your variables
local player = Players.LocalPlayer
local combatRemote = ReplicatedStorage:WaitForChild("CombatSystem"):WaitForChild("Remotes"):WaitForChild("RequestHit")
local teleportRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TeleportToPortal")

-- Configuration
local heightAbove = 7 
local distanceBehind = 1.5 
local loopSpeed = 0.1 
local weaponName = "Shadow Monarch"

-- State Tracking
local wasFarmingAizen = false
local wasFarmingYamato = false
local currentTarget = nil

-------------------------------------------------------------------------
-- ANTI-AFK SYSTEM
-------------------------------------------------------------------------
player.Idled:Connect(function()
    VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
end)

-------------------------------------------------------------------------
-- MOVERS & TARGETING FUNCTIONS
-------------------------------------------------------------------------

-- Create the Physics Movers
local alignPos = Instance.new("AlignPosition")
alignPos.Mode = Enum.PositionAlignmentMode.OneAttachment
alignPos.MaxForce = 9999999
alignPos.MaxVelocity = 500 
alignPos.Responsiveness = 200 

local alignOri = Instance.new("AlignOrientation")
alignOri.Mode = Enum.OrientationAlignmentMode.OneAttachment
alignOri.MaxTorque = 9999999
alignOri.Responsiveness = 200 

local function setupMovers(character)
	local hrp = character:WaitForChild("HumanoidRootPart", 5)
	if not hrp then return end
	
	local attachment = hrp:FindFirstChild("FarmAttachment")
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "FarmAttachment"
		attachment.Parent = hrp
	end
	
	alignPos.Attachment0 = attachment
	alignPos.Parent = hrp
	
	alignOri.Attachment0 = attachment
	alignOri.Parent = hrp
end

local function getAizen()
	local aizen = workspace:FindFirstChild("NPCs") and workspace.NPCs:FindFirstChild("AizenBoss")
	if aizen then
		local hum = aizen:FindFirstChild("Humanoid")
		local hrp = aizen:FindFirstChild("HumanoidRootPart")
		if hum and hrp and hum.Health > 0 then
			return aizen
		end
	end
	return nil
end

local function getYamato()
	local yamato = workspace:FindFirstChild("NPCs") and workspace.NPCs:FindFirstChild("YamatoBoss")
	if yamato then
		local hum = yamato:FindFirstChild("Humanoid")
		local hrp = yamato:FindFirstChild("HumanoidRootPart")
		if hum and hrp and hum.Health > 0 then
			return yamato
		end
	end
	return nil
end

local function getNextQuincy()
	local npcsFolder = workspace:FindFirstChild("NPCs")
	if not npcsFolder then return nil end

	for _, npc in ipairs(npcsFolder:GetChildren()) do
		if npc.Name ~= "AizenBoss" and npc.Name ~= "YamatoBoss" then 
			local humanoid = npc:FindFirstChild("Humanoid")
			local hrp = npc:FindFirstChild("HumanoidRootPart")
			
			if humanoid and hrp and humanoid.Health > 0 then
				return npc 
			end
		end
	end
	return nil 
end

local function ensureWeaponEquipped(character)
    if character:FindFirstChild(weaponName) then return end
    
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        local weapon = backpack:FindFirstChild(weaponName)
        if weapon then
            local humanoid = character:FindFirstChild("Humanoid")
            if humanoid then
                humanoid:EquipTool(weapon)
            end
        end
    end
end

-------------------------------------------------------------------------
-- UI SETUP
-------------------------------------------------------------------------

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Auto Farm Hub",
    SubTitle = "Bleach Farm",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true, 
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "swords" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

local Options = Fluent.Options

do
    Tabs.Main:AddToggle("FarmQuincy", {Title = "Auto Farm Quincy", Default = false })
    Tabs.Main:AddToggle("FarmAizen", {Title = "Auto Farm Quincy + Aizen Boss", Default = false })
    Tabs.Main:AddToggle("FarmYamato", {Title = "Auto Farm Quincy + Yamato Boss", Default = false })
    Tabs.Main:AddToggle("FarmAll", {Title = "Auto Farm Quincy + Aizen + Yamato", Default = false })
end

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("FluentScriptHub")
SaveManager:SetFolder("FluentScriptHub/BleachGame")

InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)

Fluent:Notify({
    Title = "Script Loaded",
    Content = "Anti-AFK is active. Toggles are ready.",
    Duration = 5
})

-------------------------------------------------------------------------
-- FARMING LOGIC
-------------------------------------------------------------------------

-- NOCLIP
RunService.Stepped:Connect(function()
    local isFarmingToggle = (Options.FarmQuincy and Options.FarmQuincy.Value) or 
                            (Options.FarmAizen and Options.FarmAizen.Value) or 
                            (Options.FarmYamato and Options.FarmYamato.Value) or
                            (Options.FarmAll and Options.FarmAll.Value)
	
    if isFarmingToggle and currentTarget and player.Character then
		for _, part in ipairs(player.Character:GetDescendants()) do
			if part:IsA("BasePart") and part.CanCollide then
				part.CanCollide = false
			end
		end
	end
end)

-- Main loop
task.spawn(function()
	while true do
        local farmQ = Options.FarmQuincy and Options.FarmQuincy.Value
        local farmA = Options.FarmAizen and Options.FarmAizen.Value
        local farmY = Options.FarmYamato and Options.FarmYamato.Value
        local farmAll = Options.FarmAll and Options.FarmAll.Value
        
        local isFarming = farmQ or farmA or farmY or farmAll

		local character = player.Character
		
		if isFarming and character and character:FindFirstChild("HumanoidRootPart") and character:FindFirstChild("Humanoid") then
			local humanoid = character.Humanoid
			
			if humanoid.Health > 0 then
				
				if alignPos.Parent ~= character.HumanoidRootPart then
					setupMovers(character)
				end
				
				ensureWeaponEquipped(character)
				
				-- Check for bosses based on active toggles
				local aizenBoss = (farmA or farmAll) and getAizen() or nil
				local yamatoBoss = (farmY or farmAll) and getYamato() or nil
				
				if aizenBoss then
                    if wasFarmingYamato then
                        wasFarmingYamato = false
                    end
					if not wasFarmingAizen then
						wasFarmingAizen = true
						currentTarget = aizenBoss
						teleportRemote:FireServer("HuecoMundo")
						task.wait(1) 
					else
						currentTarget = aizenBoss
					end
					
				elseif yamatoBoss then
					if wasFarmingAizen then
						wasFarmingAizen = false
						currentTarget = nil
						humanoid.Health = 0
						task.wait(3)
						continue 
					end
					
                    if not wasFarmingYamato then
                        wasFarmingYamato = true
                        currentTarget = yamatoBoss
                        teleportRemote:FireServer("Judgement")
                        task.wait(1)
                    else
					    currentTarget = yamatoBoss
                    end
					
				else
					if wasFarmingAizen or wasFarmingYamato then
						wasFarmingAizen = false
                        wasFarmingYamato = false
						currentTarget = nil
						humanoid.Health = 0
						task.wait(3)
						continue 
					end
					
					if currentTarget then
						local hum = currentTarget:FindFirstChild("Humanoid")
						local hrp = currentTarget:FindFirstChild("HumanoidRootPart")
						if not hum or not hrp or hum.Health <= 0 then
							currentTarget = nil 
						end
					end
					
					if not currentTarget then
						currentTarget = getNextQuincy()
					end
				end
				
				if currentTarget and currentTarget:FindFirstChild("HumanoidRootPart") then
                    character.HumanoidRootPart.Anchored = false
					
                    if currentTarget.Name == "YamatoBoss" then
                        alignPos.MaxVelocity = 50 
                    else
                        alignPos.MaxVelocity = 500 
                    end
					
                    alignPos.Enabled = true
					alignOri.Enabled = true
					
					local targetHRP = currentTarget.HumanoidRootPart
					
					local goalPos = (targetHRP.CFrame * CFrame.new(0, heightAbove, distanceBehind)).Position
					local goalCFrame = CFrame.lookAt(goalPos, targetHRP.Position)
					
					alignPos.Position = goalPos
					alignOri.CFrame = goalCFrame
					
					combatRemote:FireServer() 
				else
					alignPos.Enabled = false
					alignOri.Enabled = false
                    character.HumanoidRootPart.Anchored = true
				end
			end
        else
            alignPos.Enabled = false
            alignOri.Enabled = false
            if character and character:FindFirstChild("HumanoidRootPart") then
                character.HumanoidRootPart.Anchored = false
            end
		end
		
		task.wait(loopSpeed)
	end
end)

SaveManager:LoadAutoloadConfig()