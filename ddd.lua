local Players = game:GetService("Players")
local player = Players.LocalPlayer
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- === Настройки ===
local isSearching = false
local autoAttackEnabled = false
local HEIGHT_OFFSET = 3
local EGG_SPEED = 50
local NPC_TELEPORT_DELAY = 0.3
local BLACKLIST = {"WhiteBas", "CrackedBas", "Flying", "Dead"}
local MAX_WAIT_TIME = 25
local NOCLIP_ENABLED = true
local noclipConnection = nil

-- === Пути === 
local NPCFolder = workspace:FindFirstChild("#GAME") and workspace["#GAME"].Folders and 
                 workspace["#GAME"].Folders.HumanoidFolder and 
                 workspace["#GAME"].Folders.HumanoidFolder:FindFirstChild("NPCFolder")
local targetFolder = workspace:FindFirstChild("#GAME") and workspace["#GAME"].Folders and 
                    workspace["#GAME"].Folders:FindFirstChild("DumpFolder") or workspace

-- === Приоритеты яиц ===
local EGG_PRIORITY_GROUPS = {
    -- Группа 1 (высший приоритет)
    { "Burnt Egg", "Berend Egg", "Metal Egg", "Primo Egg", "Co Egg", "R6 Egg", "Hellfire Egg", "Enraged Egg", "Biggester Egg"
    },
    -- Группа 2 (средний приоритет)
    {
        "Amethyst Egg", "Ruby Egg", "Emerald Egg", "BULL Egg", "BULLKER Egg", "Banana Egg", "Bananade Egg", "Boeman Egg", "Bunny Egg", "Buoyant Egg", "Cheese Egg", 
  "Delicious Egg", "Elf Egg", "Fur Egg", "Ginger Egg", "Headless Egg", "Jack Egg", "Jumperino Egg", "Mighty Egg", "Moai Egg", "Noob Egg", "Old Egg", "Party Egg", "Pouwk Egg", "Pouwker Egg", "Raffle Egg", "Santa Egg", "Skeleton Egg", "Yoss Egg", "BOSS Egg", "Baby Egg", "Bas Egg", 
  "Dark Egg", "Diamond Egg", "Error Egg", "Fattest Egg", "Ghost Egg", "Golden Egg", "Greasy Egg", "Happy Egg", "Hateful Egg", "Invincible Egg", "Invisible Egg", "Nano Egg", "Nasty Egg", "Not Egg", "Nuke Egg", "Paper Egg", "R6 Egg", 
  "Rotten Egg", "Rusty Egg", "SigmaBloxian Egg", "Silver Egg", "Skinny Egg", 
  "Smallest Egg",
  "Turd Egg", "Wide Egg", "Zombie Egg", "Werewolf Egg", "Bomb Egg"
    },
    -- Группа 3 (низкий приоритет, по желанию)
    {
        -- "Common Egg",
        -- "Basic Egg"
    }
}

-- === Скорость ===
local speedCheckCount = 0
local MAX_SPEED_CHECKS = 10
local speedHistory = {} -- Хранение всех собранных значений скорости

-- === Функция определения скорости (обновлённая) ===
local function updateEggSpeed()
    if speedCheckCount >= MAX_SPEED_CHECKS then return end
    local playerHumanoidFolder = workspace["#GAME"] and workspace["#GAME"].Folders and 
                                 workspace["#GAME"].Folders.HumanoidFolder and 
                                 workspace["#GAME"].Folders.HumanoidFolder:FindFirstChild("PlayerFolder") and 
                                 workspace["#GAME"].Folders.HumanoidFolder.PlayerFolder:FindFirstChild(player.Name)
    if playerHumanoidFolder and playerHumanoidFolder:FindFirstChild("Humanoid") then
        local baseSpeed = playerHumanoidFolder.Humanoid.WalkSpeed
        table.insert(speedHistory, baseSpeed)
        speedCheckCount += 1
        print("[" .. speedCheckCount .. "/" .. MAX_SPEED_CHECKS .. "] Записана скорость: " .. baseSpeed)
        if speedCheckCount == MAX_SPEED_CHECKS then
            -- Подсчет частоты встречаемости скоростей
            local frequency = {}
            for _, speed in ipairs(speedHistory) do
                if frequency[speed] then
                    frequency[speed] = frequency[speed] + 1
                else
                    frequency[speed] = 1
                end
            end
            -- Найти наиболее частую скорость
            local mostFrequentSpeed = nil
            local maxCount = 0
            for speed, count in pairs(frequency) do
                if count > maxCount or (count == maxCount and speed > mostFrequentSpeed) then
                    mostFrequentSpeed = speed
                    maxCount = count
                end
            end
            -- Установить итоговую скорость
            EGG_SPEED = math.max(1, mostFrequentSpeed)
            print("Установлена итоговая скорость полёта к яйцам: " .. EGG_SPEED)
        end
    else
        warn("Не удалось найти персонажа игрока для определения скорости")
        EGG_SPEED = 50 -- Резервная скорость
    end
end

-- === Проверка черного списка ===
local function isNPCBlacklisted(npcName)
    for _, blacklistedName in ipairs(BLACKLIST) do
        if string.find(npcName, blacklistedName) then
            return true
        end
    end
    return false
end

-- === NoClip ===
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

-- === Поиск яйца ===
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

-- === Получение HRP ===
local function getHRP()
    if not player or not player.Character then
        warn("Персонаж ещё не загружен. Жду...")
        local startTime = os.clock()
        while os.clock() - startTime < MAX_WAIT_TIME do
            if player and player.Character then
                break
            end
            task.wait(0.1)
        end
        if not player or not player.Character then
            warn("Персонаж так и не загрузился")
            return nil
        end
    end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        warn("HumanoidRootPart не найден. Жду...")
        local startTime = os.clock()
        while os.clock() - startTime < MAX_WAIT_TIME do
            hrp = player.Character:FindFirstChild("HumanoidRootPart")
            if hrp then break end
            task.wait(0.1)
        end
    end
    if not hrp then
        warn("HumanoidRootPart не найден после ожидания")
        return nil
    end
    return hrp
end

-- === Перемещение к яйцу ===
local function moveToEggWithTween(targetPosition)
    local hrp = getHRP()
    if not hrp then return nil end
    updateEggSpeed()
    local distance = (targetPosition - hrp.Position).Magnitude
    local duration = distance / EGG_SPEED
    local tween = TweenService:Create(
        hrp,
        TweenInfo.new(duration, Enum.EasingStyle.Linear),
        {CFrame = CFrame.new(targetPosition, targetPosition + Vector3.new(0, 0, -1))}
    )
    tween:Play()
    return tween
end

-- === Сбор яйца ===
local function autoCollectEgg(egg)
    if not egg or not isSearching then return false end
    local hrp = getHRP()
    if not hrp then return false end
    local prompt
    local success, err = pcall(function()
        prompt = egg:FindFirstChildOfClass("ProximityPrompt") or
                (egg:IsA("Model") and egg.PrimaryPart and egg.PrimaryPart:FindFirstChildOfClass("ProximityPrompt"))
    end)
    if not success or not prompt then
        warn("Не найден ProximityPrompt у яйца")
        return false
    end
    local targetPos
    if egg:IsA("BasePart") then
        targetPos = egg.Position + Vector3.new(0, HEIGHT_OFFSET, 0)
    elseif egg:IsA("Model") and egg.PrimaryPart then
        targetPos = egg.PrimaryPart.Position + Vector3.new(0, HEIGHT_OFFSET, 0)
    else
        warn("Неверный тип объекта яйца")
        return false
    end
    local tween = moveToEggWithTween(targetPos)
    local startTime = os.clock()
    local maxTime = 8
    while os.clock() - startTime < maxTime and isSearching do
        if not egg or not egg:IsDescendantOf(workspace) then
            tween:Cancel()
            return true
        end
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

-- === Атака NPC ===
local function teleportToNPC(npc)
    if not npc then return end
    local hrp = getHRP()
    if not hrp then return end
    local rootPart = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("UpperTorso")
    if not rootPart then return end
    hrp.CFrame = CFrame.new(rootPart.Position + Vector3.new(0, HEIGHT_OFFSET, 0))
end

local function attackNPC(npc)
    if not npc or not isSearching then return end
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

local function attackNPCs()
    if not isSearching or not NPCFolder then return end
    for _, npc in ipairs(NPCFolder:GetChildren()) do
        if not isSearching then break end
        if isNPCBlacklisted(npc.Name) then continue end
        if npc:FindFirstChild("Humanoid") and npc.Humanoid.Health > 0 then
            attackNPC(npc)
            task.wait(NPC_TELEPORT_DELAY)
        end
    end
end

-- === Сбор яиц с приоритетами ===
local function collectEggs()
    if not isSearching then return false end
    -- Перебор по уровням приоритета
    for _, priorityGroup in ipairs(EGG_PRIORITY_GROUPS) do
        for _, eggName in ipairs(priorityGroup) do
            if not isSearching then return false end
            local egg = findEgg(eggName)
            if egg then
                print("🎯 Найдено яйцо с приоритетом: " .. eggName)
                if autoCollectEgg(egg) then
                    task.wait(0.5)
                    return true
                end
            end
        end
    end
    return false
end

-- === Главный цикл ===
local function mainLoop()
    while isSearching do
        local success, err = pcall(function()
            if not collectEggs() then
                if autoAttackEnabled then
                    attackNPCs()
                end
            end
        end)
        if not success then
            warn("Ошибка в главном цикле: " .. tostring(err))
        end
        task.wait(0.1)
    end
end

-- === Управление ===
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
    elseif input.KeyCode == Enum.KeyCode.O then
        autoAttackEnabled = not autoAttackEnabled
        print(autoAttackEnabled and "Автоатака включена" or "Автоатака выключена")
    end
end)

-- === Удаление объектов ===
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

-- === Инициализация ===
task.spawn(function()
    local mapFolder = workspace:FindFirstChild("#GAME") and workspace["#GAME"]:FindFirstChild("Map")
    if mapFolder then
        safeDelete(mapFolder, "Jeep")
    else
        warn("Папка '#GAME.Map' не найдена!")
    end
    local housePath = mapFolder and mapFolder:FindFirstChild("Houses") and 
                     mapFolder.Houses:FindFirstChild("Blue House")
    local roomsToDelete = {
        "LivingRoom", "Kitchen", "Small Bedroom",
        "WorkRoom", "Bathroom", "Big Bedroom"
    }
    safeDeleteRooms(housePath, roomsToDelete)
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

-- === Автоэкипировка ===
local TOGGLE_KEY = Enum.KeyCode.Y
local TOOL_PRIORITY = {
    "Maus",
    "M1 Abrams",
    "Pine Tree",
    "King Slayer",
}
local isRunning = true
local function EquipTool()
    if not isRunning then return end
    local Character = player.Character or player.CharacterAdded:Wait()
    local Backpack = player:FindFirstChildOfClass("Backpack")
    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
    if not Backpack or not Humanoid then return end
    for _, toolName in ipairs(TOOL_PRIORITY) do
        local Tool = Backpack:FindFirstChild(toolName) or Character:FindFirstChild(toolName)
        if Tool and Tool:IsA("Tool") then
            if not Character:FindFirstChild(Tool.Name) then
                Humanoid:EquipTool(Tool)
                print("🔹 [Auto-Equip] Взят: " .. Tool.Name)
            end
            return
        end
    end
end

player.CharacterAdded:Connect(function()
    task.wait(2)
    if isRunning then
        EquipTool()
    end
end)

RunService.Heartbeat:Connect(function()
    if isRunning then
        EquipTool()
        task.wait(1.5)
    end
end)

UserInputService.InputBegan:Connect(function(Input, _)
    if Input.KeyCode == TOGGLE_KEY then
        isRunning = not isRunning
        print(isRunning and "🟢 [Auto-Equip] Включено" or "🔴 [Auto-Equip] Выключено")
    end
end)

EquipTool()
print("🛠 [Auto-Equip] Готово! Нажми Y для включения/выключения.")

-- === Anti-AFK ===
loadstring(game:HttpGet("https://raw.githubusercontent.com/ArgetnarYT/scripts/main/AntiAfk2.lua "))()

-- === Включение NoClip при запуске ===
enableNoclip()
print("Постоянный NoClip активирован (включен по умолчанию)")
print("Нажмите N для отключения NoClip")
print("Скорость полёта к яйцам: " .. EGG_SPEED)
print("Автопоиск и атака: Нажмите P для старта/остановки")
print("Нажмите O для включения/выключения автоатаки")

wait(1)

-- === Остальная часть скрипта (например, Auto Attack) ===

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

local priorityNames1 = { "Amethyst", "Ruby", "Emerald", "Diamond", "BULL" }
local priorityNames2 = { "Golden" }

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


wait(1)

-- Freeze Script (работает после смерти)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local function freezePlayer(player)
    local character = player.Character or player.CharacterAdded:Wait()
    
    -- Функция для применения Freeze
    local function applyFreeze(char)
        if not char then return end
        
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Anchored = true  -- Замораживаем часть
                part.Velocity = Vector3.new(0, 0, 0)
                part.RotVelocity = Vector3.new(0, 0, 0)
            end
        end
    end
    
    -- Применяем Freeze к текущему персонажу
    applyFreeze(character)
    
    -- Следим за изменением персонажа (после респауна)
    player.CharacterAdded:Connect(function(newCharacter)
        wait(0.1) -- Небольшая задержка для загрузки персонажа
        applyFreeze(newCharacter)
    end)
    
    -- Непрерывная проверка (дополнительная страховка)
    local connection
    connection = RunService.Heartbeat:Connect(function()
        local currentChar = player.Character
        if currentChar then
            for _, part in pairs(currentChar:GetDescendants()) do
                if part:IsA("BasePart") and not part.Anchored then
                    part.Anchored = true
                    part.Velocity = Vector3.new(0, 0, 0)
                    part.RotVelocity = Vector3.new(0, 0, 0)
                end
            end
        end
    end)
    
    -- Возвращаем функцию для остановки Freeze
    return function()
        if connection then
            connection:Disconnect()
        end
    end
end

-- Пример использования:
-- Заморозить конкретного игрока
local targetPlayer = Players:FindFirstChild("PlayerName") -- Замените на имя игрока
if targetPlayer then
    local unfreezeFunction = freezePlayer(targetPlayer)
    -- unfreezeFunction() -- Вызовите эту функцию для разморозки
end

-- Или заморозить всех игроков
for _, player in pairs(Players:GetPlayers()) do
    freezePlayer(player)
end

-- Автоматически замораживать новых игроков
Players.PlayerAdded:Connect(function(player)
    freezePlayer(player)
end)

wait(1)

-- Ждём необходимые сервисы
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Events = ReplicatedStorage:WaitForChild("Events")
local ClickEvent = Events:WaitForChild("Click")

-- Запускаем бесконечный цикл, который вызывает событие каждые 0.1 секунды
while true do
    ClickEvent:FireServer()
    task.wait(0.005) 
end
