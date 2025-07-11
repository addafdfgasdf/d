local Players = game:GetService("Players")
local player = Players.LocalPlayer
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Настройки
local isSearching = false
local HEIGHT_OFFSET = 3
local EGG_SPEED = 50 -- Скорость полёта к яйцам (можно изменять)
local NPC_TELEPORT_DELAY = 0.3 -- Задержка между телепортами к NPC
local BLACKLIST = {"WhiteBas", "CrackedBas", "Flying Noob", "Dead Noob"}
local AUTO_ATTACK = true -- Включить автоатаку NPC
local MAX_WAIT_TIME = 15 -- Максимальное время ожидания объектов (секунд)

-- NoClip переменные
local NOCLIP_ENABLED = true
local noclipConnection = nil

-- Пути поиска
local NPCFolder = workspace:FindFirstChild("#GAME") and workspace["#GAME"]:FindFirstChild("Folders") and 
                 workspace["#GAME"].Folders:FindFirstChild("HumanoidFolder") and 
                 workspace["#GAME"].Folders.HumanoidFolder:FindFirstChild("NPCFolder")

local targetFolder = workspace:FindFirstChild("#GAME") and workspace["#GAME"]:FindFirstChild("Folders") and 
                    workspace["#GAME"].Folders:FindFirstChild("DumpFolder") or workspace

-- Список всех возможных яиц
local eggNames = {
    "Nasty Egg"
}

-- Функция для проверки, содержит ли имя NPC запрещенную подстроку
local function isNPCBlacklisted(npcName)
    for _, blacklistedName in ipairs(BLACKLIST) do
        if string.find(npcName, blacklistedName) then
            return true
        end
    end
    return false
end

-- Функция NoClip
local function enableNoclip()
    if noclipConnection then noclipConnection:Disconnect() end
    
    noclipConnection = RunService.Stepped:Connect(function()
        if player.Character then
            for _, part in pairs(player.Character:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end)
end

-- Отключение NoClip
local function disableNoclip()
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end
    
    if player.Character then
        for _, part in pairs(player.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end
end

-- Функция для проверки наличия яиц с защитой от ошибок
local function findEgg(eggName)
    if not targetFolder then return nil end
    
    local success, egg = pcall(function()
        return targetFolder:FindFirstChild(eggName, false) or
               targetFolder:FindFirstChild(eggName.." Egg", false) or
               targetFolder:FindFirstChild("Egg of "..eggName, false)
    end)
    
    if success and egg and (egg:IsA("Model") or egg:IsA("BasePart")) then
        return egg
    end
    return nil
end

-- Улучшенная функция для получения HumanoidRootPart с таймаутом
local function getHRP()
    if not player or not player.Character then
        local startTime = os.clock()
        while os.clock() - startTime < MAX_WAIT_TIME do
            if player and player.Character then
                break
            end
            task.wait(0.1)
        end
        if not player or not player.Character then return nil end
    end

    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        local startTime = os.clock()
        while os.clock() - startTime < MAX_WAIT_TIME do
            hrp = player.Character:FindFirstChild("HumanoidRootPart")
            if hrp then break end
            task.wait(0.1)
        end
    end
    
    return hrp
end

-- Движение к яйцу через TweenService
local function moveToEggWithTween(targetPosition)
    local hrp = getHRP()
    if not hrp then return nil end
    
    -- Вычисляем расстояние и время для Tween
    local distance = (targetPosition - hrp.Position).Magnitude
    local duration = distance / EGG_SPEED
    
    -- Создаем Tween
    local tween = TweenService:Create(
        hrp,
        TweenInfo.new(duration, Enum.EasingStyle.Linear),
        {CFrame = CFrame.new(targetPosition, targetPosition + Vector3.new(0, 0, -1))}
    )
    
    -- Запускаем Tween
    tween:Play()
    
    return tween
end

-- Телепортация к NPC с проверками
local function teleportToNPC(npc)
    if not npc then return end
    
    local hrp = getHRP()
    if not hrp then return end
    
    local rootPart = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("UpperTorso")
    if not rootPart then return end
    
    hrp.CFrame = CFrame.new(rootPart.Position + Vector3.new(0, HEIGHT_OFFSET, 0))
end

-- Автоподбор яйца с TweenService
local function autoCollectEgg(egg)
    if not egg or not isSearching then return false end
    
    local hrp = getHRP()
    if not hrp then return false end

    local prompt
    local success, err = pcall(function()
        prompt = egg:FindFirstChildOfClass("ProximityPrompt") or
                (egg:IsA("Model") and egg.PrimaryPart and egg.PrimaryPart:FindFirstChildOfClass("ProximityPrompt"))
    end)
    
    if not success or not prompt then return false end
    
    local targetPos
    if egg:IsA("BasePart") then
        targetPos = egg.Position + Vector3.new(0, HEIGHT_OFFSET, 0)
    elseif egg:IsA("Model") and egg.PrimaryPart then
        targetPos = egg.PrimaryPart.Position + Vector3.new(0, HEIGHT_OFFSET, 0)
    end
    
    if not targetPos then return false end
    
    local tween = moveToEggWithTween(targetPos)
    local startTime = os.clock()
    local maxTime = 8
    
    while os.clock() - startTime < maxTime and isSearching do
        if not egg or not egg:IsDescendantOf(workspace) then
            tween:Cancel()
            return true
        end
        
        -- Проверяем расстояние и активируем промпт
        if (hrp.Position - targetPos).Magnitude < 10 then
            pcall(function()
                fireproximityprompt(prompt, 3)
            end)
            tween:Cancel()
            return true
        end
        
        task.wait()
    end
    
    tween:Cancel()
    return false
end

-- Атака NPC с проверками
local function attackNPC(npc)
    if not npc or not isSearching then return end
    
    -- Проверяем, не входит ли NPC в черный список
    if isNPCBlacklisted(npc.Name) then return end
    
    local humanoid = npc:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end
    
    local hrp = getHRP()
    if not hrp then return end
    
    teleportToNPC(npc)
    
    local npcRoot = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("UpperTorso")
    if npcRoot and (hrp.Position - npcRoot.Position).Magnitude < 10 then
        pcall(function()
            humanoid:TakeDamage(10)
        end)
    end
end

-- Поиск и сбор яиц с защитой от ошибок
local function collectEggs()
    if not isSearching then return false end
    
    local hrp = getHRP()
    if not hrp then return false end

    for _, eggName in ipairs(eggNames) do
        if not isSearching then break end
        
        local egg = findEgg(eggName)
        if egg then
            if autoCollectEgg(egg) then
                task.wait(0.5)
                return true
            end
        end
    end
    return false
end

-- Телепортация и атака NPC с проверками
local function attackNPCs()
    if not AUTO_ATTACK or not isSearching or not NPCFolder then return end
    
    for _, npc in ipairs(NPCFolder:GetChildren()) do
        if not isSearching then break end
        
        -- Пропускаем NPC из черного списка
        if isNPCBlacklisted(npc.Name) then continue end
        
        if npc:FindFirstChild("Humanoid") and npc.Humanoid.Health > 0 then
            attackNPC(npc)
            task.wait(NPC_TELEPORT_DELAY)
        end
    end
end

-- Главный цикл с обработкой ошибок
local function mainLoop()
    while isSearching do
        local success, err = pcall(function()
            if not collectEggs() then
                attackNPCs()
            end
        end)
        
        if not success then
            warn("Ошибка в главном цикле: " .. tostring(err))
        end
        
        task.wait(0.1)
    end
end

-- Управление (P для вкл/выкл поиска, N для вкл/выкл NoClip)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.P then
        isSearching = not isSearching
        
        if isSearching then
            print("Автопоиск и атака активированы. Нажмите P для остановки")
            task.spawn(mainLoop)
        else
            print("Автопоиск и атака остановлены")
            local hrp = getHRP()
            if hrp then hrp.Velocity = Vector3.new() end
        end
    elseif input.KeyCode == Enum.KeyCode.N then
        NOCLIP_ENABLED = not NOCLIP_ENABLED
        if NOCLIP_ENABLED then
            enableNoclip()
            print("NoClip включен")
        else
            disableNoclip()
            print("NoClip выключен")
        end
    end
end)

-- Включение NoClip при запуске
enableNoclip()
print("Постоянный NoClip активирован (включен по умолчанию)")
print("Нажмите N для отключения NoClip")
print("Скорость полёта к яйцам: " .. EGG_SPEED)
print("Автопоиск и атака: Нажмите P для старта/остановки")

-- Функция для безопасного удаления объектов
local function safeDelete(objects, name)
    if not objects then
        warn("Не найдена папка " .. tostring(name))
        return
    end
    
    for _, obj in pairs(objects:GetDescendants()) do
        if obj.Name == name then
            pcall(function()
                obj:Destroy()
                print("Удален объект " .. name .. ": " .. obj:GetFullName())
            end)
        end
    end
end

-- Функция для безопасного удаления комнат
local function safeDeleteRooms(housePath, roomNames)
    if not housePath then
        warn("Дом не найден!")
        return
    end

    local roomsFolder = housePath:FindFirstChild("Rooms")
    if not roomsFolder then
        warn("Папка 'Rooms' не найдена!")
        return
    end
    
    for _, roomName in ipairs(roomNames) do
        local room = roomsFolder:FindFirstChild(roomName)
        if room then
            pcall(function()
                room:Destroy()
                print("Комната '" .. roomName .. "' удалена")
            end)
        else
            warn("Комната '" .. roomName .. "' не найдена!")
        end
    end
end

-- Инициализация при запуске
task.spawn(function()
    -- Удаление Jeep объектов
    local mapFolder = workspace:FindFirstChild("#GAME") and workspace["#GAME"]:FindFirstChild("Map")
    if mapFolder then
        safeDelete(mapFolder, "Jeep")
    else
        warn("Папка '#GAME.Map' не найдена!")
    end

    -- Удаление комнат
    local housePath = mapFolder and mapFolder:FindFirstChild("Houses") and 
                     mapFolder.Houses:FindFirstChild("Blue House")
    local roomsToDelete = {
        "LivingRoom", "Kitchen", "Small Bedroom",
        "WorkRoom", "Bathroom", "Big Bedroom"
    }
    safeDeleteRooms(housePath, roomsToDelete)

    -- Удаление Exterior и Backyard
    if housePath then
        local exterior = housePath:FindFirstChild("Exterior")
        if exterior then
            pcall(function() exterior:Destroy() end)
        end
        
        local backyard = mapFolder.Houses:FindFirstChild("Backyard")
        if backyard then
            pcall(function() backyard:Destroy() end)
        end
    end

    print("Скрипт удаления завершен!")
end)

wait(1)

local Player = game:GetService("Players").LocalPlayer
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local TOGGLE_KEY = Enum.KeyCode.Y -- Клавиша для отключения
local TOOL_NAME = "King Slayer" -- Название инструмента (можешь поменять)

local isRunning = true

-- Функция для поиска и экипировки инструмента
local function EquipTool()
    if not isRunning then return end
    
    local Character = Player.Character or Player.CharacterAdded:Wait()
    local Backpack = Player:FindFirstChildOfClass("Backpack")
    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
    
    if not Backpack or not Humanoid then return end

    -- Ищем инструмент в инвентаре
    local Tool = Backpack:FindFirstChild(TOOL_NAME) or Character:FindFirstChild(TOOL_NAME)
    
    -- Если нашли - экипируем
    if Tool and not Character:FindFirstChild(Tool.Name) then
        Humanoid:EquipTool(Tool)
        print("🔹 [Auto-Equip] Взят: " .. TOOL_NAME)
    end
end

-- Отслеживаем смерть/респавн
Player.CharacterAdded:Connect(function()
    task.wait(2) -- Ждём загрузку
    if isRunning then
        EquipTool()
    end
end)

-- Проверяем инвентарь каждую секунду
RunService.Heartbeat:Connect(function()
    if isRunning then
        EquipTool()
        task.wait(1) -- Задержка, чтобы не грузить игру
    end
end)

-- Включение/выключение на "T"
UIS.InputBegan:Connect(function(Input, _)
    if Input.KeyCode == TOGGLE_KEY then
        isRunning = not isRunning
        print(isRunning and "🟢 [Auto-Equip] Включено" or "🔴 [Auto-Equip] Выключено")
    end
end)

-- Первый запуск
EquipTool()
print("🛠 [Auto-Equip] Готово! Нажми T для отключения.")

wait(1)

loadstring(game:HttpGet("https://raw.githubusercontent.com/ArgetnarYT/scripts/main/AntiAfk2.lua"))()

wait(1)

--[[
	WARNING: Heads up! This script has not been verified by ScriptBlox. Use at your own risk!
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
	Players.PlayerAdded:Wait()
	LocalPlayer = Players.LocalPlayer
end

local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse() -- Retained as it might be needed for other game interactions, though not directly by this script's core logic.

local gameFolder = Workspace:WaitForChild("#GAME", 10)
local foldersFolder = gameFolder and gameFolder:WaitForChild("Folders", 5)
local humanoidFolder = foldersFolder and foldersFolder:WaitForChild("HumanoidFolder", 5)
local mainFolder = humanoidFolder and humanoidFolder:WaitForChild("NPCFolder", 5) -- Your target folder

local eventsFolder = ReplicatedStorage:WaitForChild("Events", 10)
local remote = eventsFolder and eventsFolder:WaitForChild("MainAttack", 5)

if not mainFolder then
	warn("Auto Attack: Could not find NPCFolder at expected path.")
	return
end
if not remote then
	warn("Auto Attack: Could not find MainAttack RemoteEvent.")
	return
end


local isActive = false

local priorityNames1 = { "Amethyst", "Ruby", "Emerald", "Diamond", "Golden", "Silver" }
local priorityNames2 = { "Werewolf", "Berend" }

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.T then
		isActive = not isActive
		print(isActive and "Auto Attack ON" or "Auto Attack OFF")
	end
end)

local function getDeadNPCs()
	local deadList = {}
	if not mainFolder then return deadList end

	for _, npc in ipairs(mainFolder:GetChildren()) do
		if npc:IsA("Model") then
			local humanoid = npc:FindFirstChildOfClass("Humanoid")
			-- Check if Humanoid exists AND (Health is 0 or less OR its name contains "Dead")
			if humanoid and (humanoid.Health <= 0 or string.find(humanoid.Name, "Dead", 1, true)) then
				table.insert(deadList, npc)
			end
		end
	end
	return deadList
end

local function getPriorityTarget(npcList)
	local function findByPriority(list, keywords)
		for _, keyword in ipairs(keywords) do
			for _, npc in ipairs(list) do
				if npc.Name:find(keyword, 1, true) then
					return npc
				end
			end
		end
		return nil
	end

	local target = findByPriority(npcList, priorityNames1)
	if target then return target end

	target = findByPriority(npcList, priorityNames2)
	if target then return target end

	if #npcList > 0 then
		return npcList[math.random(1, #npcList)]
	end

	return nil
end

local function getValidBodyParts(model)
	local validParts = {}
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			local isGettingEaten = part:GetAttribute("IsGettingEaten")
			if not isGettingEaten then
				table.insert(validParts, part)
			end
		end
	end
	return validParts
end

local USE_DEVIATION = true
local MAX_DEVIATION_STUDS = 0.5

RunService.Heartbeat:Connect(function()
	if not isActive then return end

	local deadNPCList = getDeadNPCs()
	if #deadNPCList == 0 then return end

	local targetNpc = getPriorityTarget(deadNPCList)
	if not targetNpc or not targetNpc.Parent then return end

	local validParts = getValidBodyParts(targetNpc)
	if #validParts == 0 then
		return
	end

	local bodyPart = validParts[math.random(1, #validParts)]

	local origin = Camera.CFrame.Position

	local targetPosition = bodyPart.Position

	if USE_DEVIATION and MAX_DEVIATION_STUDS > 0 then
		local offsetX = (math.random() - 0.5) * 2 * MAX_DEVIATION_STUDS
		local offsetY = (math.random() - 0.5) * 2 * MAX_DEVIATION_STUDS
		local offsetZ = (math.random() - 0.5) * 2 * MAX_DEVIATION_STUDS
		targetPosition = targetPosition + Vector3.new(offsetX, offsetY, offsetZ)
	end

	local direction = (targetPosition - origin).Unit

    if direction.X ~= direction.X or direction.Y ~= direction.Y or direction.Z ~= direction.Z then
        warn("Calculated NaN direction! Falling back to LookVector. Origin:", origin, "Target:", targetPosition)
        direction = Camera.CFrame.LookVector
    end

	local args = {
		[1] = {
			["AN"] = "Eat",
			["D"] = direction,
			["O"] = origin,
			["FBP"] = bodyPart
		}
	}
	remote:FireServer(unpack(args))
end)
