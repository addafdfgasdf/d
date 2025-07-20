-- === ОСНОВНЫЕ СЕРВИСЫ ===
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- === КОНФИГУРАЦИЯ (main_config.txt) ===
local CONFIG = {
    -- Основные настройки
    isSearching = false,
    HEIGHT_OFFSET = 3,
    EGG_SPEED = 50,
    NPC_TELEPORT_DELAY = 0.3,
    MAX_WAIT_TIME = 15,
    NOCLIP_ENABLED = true,
    AUTO_ATTACK = true,
    
    -- Черный список NPC
    BLACKLIST = {"WhiteBas", "CrackedBas", "Flying Noob", "Dead Noob"},
    
    -- Список яиц для сбора
    eggNames = {
        "Nasty Egg"
    },
    
    -- Приоритет инструментов
    TOOL_PRIORITY = {
        "Maus",
        "M1 Abrams",
        "Pine Tree",
        "King Slayer"
    },
    
    -- Клавиши управления
    CONTROLS = {
        SEARCH_TOGGLE = Enum.KeyCode.P,
        NOCLIP_TOGGLE = Enum.KeyCode.N,
        EQUIP_TOGGLE = Enum.KeyCode.Y,
        AUTO_ATTACK_TOGGLE = Enum.KeyCode.T
    },
    
    -- Приоритет NPC для атаки
    PRIORITY_TARGETS = {
        priority1 = {"Amethyst", "Ruby", "Emerald", "Diamond", "Golden"},
        priority2 = {"Bull"}
    }
}

-- === ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ ===
local noclipConnection = nil
local speedCheckCount = 0
local MAX_SPEED_CHECKS = 3
local isRunning = true

-- === ИНИЦИАЛИЗАЦИЯ ПУТЕЙ ===
local gameFolder = Workspace:FindFirstChild("#GAME")
local foldersFolder = gameFolder and gameFolder:FindFirstChild("Folders")
local humanoidFolder = foldersFolder and foldersFolder:FindFirstChild("HumanoidFolder")
local NPCFolder = humanoidFolder and humanoidFolder:FindFirstChild("NPCFolder")
local targetFolder = (gameFolder and gameFolder:FindFirstChild("Folders") and 
                     gameFolder.Folders:FindFirstChild("DumpFolder")) or Workspace

-- === ФУНКЦИИ ===

-- === ФУНКЦИИ ДЛЯ НАСТРОЙКИ СКОРОСТИ ===
local function updateEggSpeed()
    if speedCheckCount >= MAX_SPEED_CHECKS then return end
    
    local playerHumanoidFolder = humanoidFolder and humanoidFolder:FindFirstChild("PlayerFolder") and 
                                 humanoidFolder.PlayerFolder:FindFirstChild(player.Name)
    
    if playerHumanoidFolder and playerHumanoidFolder:FindFirstChild("Humanoid") then
        local baseSpeed = playerHumanoidFolder.Humanoid.WalkSpeed
        CONFIG.EGG_SPEED = math.max(1, baseSpeed - 10)
        speedCheckCount = speedCheckCount + 1
        print("[" .. speedCheckCount .. "/" .. MAX_SPEED_CHECKS .. "] Установлена скорость полёта к яйцам: " .. CONFIG.EGG_SPEED)
    else
        warn("Не удалось найти персонажа игрока для определения скорости")
        CONFIG.EGG_SPEED = 10
    end
end

-- === ПРОВЕРКИ И ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ===
local function isNPCBlacklisted(npcName)
    for _, blacklistedName in ipairs(CONFIG.BLACKLIST) do
        if string.find(npcName, blacklistedName) then
            return true
        end
    end
    return false
end

local function getHRP()
    if not player or not player.Character then
        warn("Персонаж ещё не загружен. Жду...")
        local startTime = os.clock()
        while os.clock() - startTime < CONFIG.MAX_WAIT_TIME do
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
        while os.clock() - startTime < CONFIG.MAX_WAIT_TIME do
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

-- === NOCLIP ФУНКЦИИ ===
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

-- === ФУНКЦИИ ДЛЯ СБОРА ЯИЦ ===
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

local function moveToEggWithTween(targetPosition)
    local hrp = getHRP()
    if not hrp then return nil end
    
    updateEggSpeed()
    
    local distance = (targetPosition - hrp.Position).Magnitude
    local duration = distance / CONFIG.EGG_SPEED
    
    local tween = TweenService:Create(
        hrp,
        TweenInfo.new(duration, Enum.EasingStyle.Linear),
        {CFrame = CFrame.new(targetPosition, targetPosition + Vector3.new(0, 0, -1))}
    )
    
    tween:Play()
    return tween
end

local function autoCollectEgg(egg)
    if not egg or not CONFIG.isSearching then return false end
    
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
        targetPos = egg.Position + Vector3.new(0, CONFIG.HEIGHT_OFFSET, 0)
    elseif egg:IsA("Model") and egg.PrimaryPart then
        targetPos = egg.PrimaryPart.Position + Vector3.new(0, CONFIG.HEIGHT_OFFSET, 0)
    else
        warn("Неверный тип объекта яйца")
        return false
    end
    
    local tween = moveToEggWithTween(targetPos)
    local startTime = os.clock()
    local maxTime = 8
    
    while os.clock() - startTime < maxTime and CONFIG.isSearching do
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

local function collectEggs()
    if not CONFIG.isSearching then return false end
    
    local hrp = getHRP()
    if not hrp then return false end
    
    for _, eggName in ipairs(CONFIG.eggNames) do
        if not CONFIG.isSearching then break end
        
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

-- === ФУНКЦИИ ДЛЯ АТАКИ NPC ===
local function teleportToNPC(npc)
    if not npc then
        warn("NPC не найден для телепортации")
        return
    end
    
    local hrp = getHRP()
    if not hrp then return end
    
    local rootPart = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("UpperTorso")
    if not rootPart then
        warn("NPC не содержит HumanoidRootPart или UpperTorso")
        return
    end
    
    hrp.CFrame = CFrame.new(rootPart.Position + Vector3.new(0, CONFIG.HEIGHT_OFFSET, 0))
end

local function attackNPC(npc)
    if not npc or not CONFIG.isSearching then return end
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
    if not CONFIG.AUTO_ATTACK or not CONFIG.isSearching or not NPCFolder then return end
    
    for _, npc in ipairs(NPCFolder:GetChildren()) do
        if not CONFIG.isSearching then break end
        if isNPCBlacklisted(npc.Name) then continue end
        
        if npc:FindFirstChild("Humanoid") and npc.Humanoid.Health > 0 then
            attackNPC(npc)
            task.wait(CONFIG.NPC_TELEPORT_DELAY)
        end
    end
end

-- === ФУНКЦИИ ДЛЯ ЭКИПИРОВКИ ИНСТРУМЕНТОВ ===
local function EquipTool()
    if not isRunning then return end
    
    local Character = player.Character or player.CharacterAdded:Wait()
    local Backpack = player:FindFirstChildOfClass("Backpack")
    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
    
    if not Backpack or not Humanoid then return end
    
    for _, toolName in ipairs(CONFIG.TOOL_PRIORITY) do
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

-- === ФУНКЦИИ ДЛЯ УДАЛЕНИЯ ОБЪЕКТОВ ===
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

-- === ОСНОВНОЙ ЦИКЛ ===
local function mainLoop()
    while CONFIG.isSearching do
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

-- === ОБРАБОТЧИКИ СОБЫТИЙ ===
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == CONFIG.CONTROLS.SEARCH_TOGGLE then
        CONFIG.isSearching = not CONFIG.isSearching
        
        if CONFIG.isSearching then
            print("Автопоиск и атака активированы. Нажмите P для остановки")
            task.spawn(mainLoop)
        else
            print("Автопоиск и атака остановлены")
            local hrp = getHRP()
            if hrp then hrp.Velocity = Vector3.new() end
        end
        
    elseif input.KeyCode == CONFIG.CONTROLS.NOCLIP_TOGGLE then
        CONFIG.NOCLIP_ENABLED = not CONFIG.NOCLIP_ENABLED
        
        if CONFIG.NOCLIP_ENABLED then
            enableNoclip()
            print("NoClip включен")
        else
            disableNoclip()
            print("NoClip выключен")
        end
        
    elseif input.KeyCode == CONFIG.CONTROLS.EQUIP_TOGGLE then
        isRunning = not isRunning
        print(isRunning and "🟢 [Auto-Equip] Включено" or "🔴 [Auto-Equip] Выключено")
        
    elseif input.KeyCode == CONFIG.CONTROLS.AUTO_ATTACK_TOGGLE then
        isActive = not isActive
        print(isActive and "Auto Attack ON" or "Auto Attack OFF")
    end
end)

-- === ИНИЦИАЛИЗАЦИЯ ПРИ ЗАПУСКЕ ===
task.spawn(function()
    local mapFolder = gameFolder and gameFolder:FindFirstChild("Map")
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

-- === ОБРАБОТЧИКИ РЕСПАВНА ===
player.CharacterAdded:Connect(function()
    task.wait(2)
    if isRunning then
        EquipTool()
    end
end)

-- === ПЕРВОНАЧАЛЬНАЯ ИНИЦИАЛИЗАЦИЯ ===
enableNoclip()
print("Постоянный NoClip активирован (включен по умолчанию)")
print("Нажмите N для отключения NoClip")
print("Скорость полёта к яйцам: " .. CONFIG.EGG_SPEED)
print("Автопоиск и атака: Нажмите P для старта/остановки")
print("🛠 [Auto-Equip] Готово! Нажми Y для включения/выключения.")
print("Auto Attack: Нажмите T для включения/выключения")

-- === ЗАГРУЗКА ДОПОЛНИТЕЛЬНЫХ СКРИПТОВ ===
RunService.Heartbeat:Connect(function()
    if isRunning then
        EquipTool()
        task.wait(1.5)
    end
end)

updateEggSpeed()
EquipTool()

-- === ЗАГРУЗКА ДОПОЛНИТЕЛЬНЫХ СКРИПТОВ ===
spawn(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/ArgetnarYT/scripts/main/AntiAfk2.lua "))()
end)

-- === АВТОАТАКА МЕРТВЫХ NPC ===
spawn(function()
    local gameFolder = Workspace:WaitForChild("#GAME", 10)
    local foldersFolder = gameFolder and gameFolder:WaitForChild("Folders", 5)
    local humanoidFolder = foldersFolder and foldersFolder:WaitForChild("HumanoidFolder", 5)
    local mainFolder = humanoidFolder and humanoidFolder:WaitForChild("NPCFolder", 5)
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
    
    local function getDeadNPCs()
        local deadList = {}
        if not mainFolder then return deadList end
        
        for _, npc in ipairs(mainFolder:GetChildren()) do
            if npc:IsA("Model") then
                local humanoid = npc:FindFirstChildOfClass("Humanoid")
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
        
        local target = findByPriority(npcList, CONFIG.PRIORITY_TARGETS.priority1)
        if target then return target end
        
        target = findByPriority(npcList, CONFIG.PRIORITY_TARGETS.priority2)
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
        local origin = Workspace.CurrentCamera.CFrame.Position
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
            direction = Workspace.CurrentCamera.CFrame.LookVector
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
end)
