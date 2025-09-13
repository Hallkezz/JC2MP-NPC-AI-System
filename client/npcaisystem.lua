---------------
--By Hallkezz--
---------------

-----------------------------------------------------------------------------------
--Settings
local countVisible = false
local blipsVisible = false
local pathsVisible = false
-----------------------------------------------------------------------------------

-----------------------------------------------------------------------------------
--Usage (Client Events)
--Events:Subscribe("NPCDeath", object, object)
-----------------------------------------------------------------------------------

-----------------------------------------------------------------------------------
--Script
class 'NPCAISystem'

function NPCAISystem:__init()
    self.actors = {}
    self.waterHeight = 200.25

    Events:Subscribe("Render", self, self.Render)
    Events:Subscribe("EntityBulletHit", self, self.EntityBulletHit)
    Events:Subscribe("VehicleCollide", self, self.OnVehicleCollide)
    Events:Subscribe("ModuleUnload", self, self.ModuleUnload)
    Events:Subscribe("PostTick", self, self.PostTick)

    Network:Subscribe("RemoveActor", self, self.RemoveActor)
    Network:Subscribe("EntityHitReact", self, self.EntityHitReact)
    Network:Subscribe("EntityDeath", self, self.EntityDeath)
    Network:Subscribe("CreateNPC", self, self.CreateNPC)
    Network:Subscribe("UpdateNPC", self, self.UpdateNPC)
    Network:Subscribe("SetWaypoints", self, self.SetWaypoints)
end

function NPCAISystem:Render()
    local bot_count = 0
    local actors = self.actors
    local baseColor = Color.White

    for id, data in pairs(actors) do
        bot_count = bot_count + 1

        if pathsVisible then
            local waypoints = data.waypoints

            if waypoints and #waypoints > 0 then
                for i = 1, #waypoints do
                    local node = waypoints[i]
                    local next_node = waypoints[i + 1]
                    local color = Color.FromHSV((i - 1) / #waypoints * 360, 0.8, 1.0)

                    local screen_pos, valid = Render:WorldToScreen(node)
                    if valid then
                        Render:DrawText(screen_pos, "#" .. tostring(i), color)
                    end

                    if next_node then
                        Render:DrawLine(node, next_node, color)
                    end
                end
            end
        end

        if blipsVisible then
            local pos = Render:WorldToMinimap(data.actor:GetPosition())
            Render:FillCircle(pos, 2, baseColor)
        end
    end

    if countVisible then
        local text = "Bots: " .. tostring(bot_count)
        local x, y = 10, 10
        Render:DrawText(Vector2(x, y), text, baseColor)
    end
end

function NPCAISystem:EntityHitReact(args)
    local npc = self.actors[args.id]

    if npc and IsValid(npc.actor) then
        npc.actor:SetHealth(args.health)

        npc.isHitReact = true
        Timer.SetTimeout(1850, function()
            if IsValid(npc.actor) then
                npc.isHitReact = false
            end
        end)

        if npc.actor:GetPosition().y > self.waterHeight then
            npc.actor:SetBaseState(AnimationState.SHitreactStumbleRandomized)
        end

        npc.actor:SetUpperBodyState(AnimationState.UbSIdle)
    end
end

function NPCAISystem:EntityDeath(id)
    local npc = self.actors[id]
    self:ActorDeath(npc, id)
end

function NPCAISystem:EntityBulletHit(args)
    local entity = args.victim
    local damage = args.damage

    for id, data in pairs(self.actors) do
        if data.actor == entity then
            Network:Send("EntityBulletHit", {id = id, damage = damage})
            break
        end
    end
end

function NPCAISystem:OnVehicleCollide(args)
    local entity = args.entity

    for id, data in pairs(self.actors) do
        if IsValid(data.actor) and data.actor:GetId() == entity:GetId() then
            local vehicle = args.attacker
            local speed = vehicle:GetLinearVelocity():Length()

            if speed > 10 then
                Network:Send("VehicleCollide", {id = id, speed = speed, vehicle_id = vehicle:GetId()})
            end

            break
        end
    end
end

function NPCAISystem:ModuleUnload()
    for id, data in pairs(self.actors) do
        if data.actor then
            data.actor:Remove()
        end
    end
    self.actors = {}
end

function NPCAISystem:PostTick(args)
    local actors = self.actors

    for id, data in pairs(actors) do
        local actor = data.actor

        if IsValid(actor) then
            local actorPos = actor:GetPosition()

            if IsNaN(actorPos) then
                self:RemoveActor(id)
            elseif IsValid(data.target) then
                if actor:GetHealth() > 0 and not data.isHitReact then
                    local raycast = Physics:Raycast(actorPos, Vector3.Down, 0, 25)

                    if raycast and raycast.distance > 20 then
                        actor:SetBaseState(AnimationState.SFall)
                    else
                        if not data.lastPathUpdate or data.lastPathUpdate:GetSeconds() >= 0.01 then
                            data.lastPathUpdate:Restart()

                            actor:FindShortestPath(data.target:GetPosition(), 0, 0, function(args)
                                if args.state == PathFindState.PathUpdate and args.waypoints then
                                    local actorPos = actor:GetPosition()
                                    local targetPos = data.target:GetPosition()

                                    Network:Send("UpdateNPCPosition", {id = id, position = actorPos})

                                    local actorRay = Physics:Raycast(actorPos + Vector3.Up * 2, Vector3.Up, 0, 200)
                                    local targetRay = Physics:Raycast(targetPos, Vector3.Up, 0, 200)

                                    local actorUpCheck = actorRay and actorRay.distance > 150
                                    local targetUpCheck = targetRay and targetRay.distance > 150

                                    for _, v in ipairs(args.waypoints) do
                                        if actorUpCheck or targetUpCheck then
                                            local height = Physics:GetTerrainHeight(v) or 0
                                            ray = Physics:Raycast(Vector3(v.x, height - 120 + actorPos.y, v.z), Vector3.Down, 0, 200)
                                        else
                                            ray = Physics:Raycast(Vector3(v.x, targetPos.y - 1080 + actorPos.y, v.z), Vector3.Down, 0, 5)
                                        end

                                        v.y = (ray and ray.position and ray.position.y) or targetPos.y
                                    end
                                    Network:Send("SetWaypoints", {
                                        id = id,
                                        waypoints = args.waypoints,
                                        waypointIndex = 1,
                                        target = data.target
                                    })
                                elseif args.state == PathFindState.PathFailed then
                                    print("Pathfinding failed for actor id:", id)
                                    Network:Send("SetWaypoints", {
                                        id = id,
                                        waypoints = {},
                                        waypointIndex = 1,
                                        target = data.target
                                    })
                                end
                            end)
                        end

                        local distanceToTarget = actorPos:Distance(data.target:GetPosition())
                        local isAiming = false
                        local isWater = actorPos.y < self.waterHeight

                        if distanceToTarget > 15 then
                            if data.waypoints and data.waypointIndex <= #data.waypoints then
                                local targetPos = data.waypoints[data.waypointIndex]
                                local dir = targetPos - actorPos

                                if dir:Length() < 1.5 then
                                    data.waypointIndex = data.waypointIndex + 1
                                else
                                    local dirNorm = dir:Normalized()
                                    dirNorm.y = 0
                                    if dirNorm:Length() > 0 then
                                        local currentAngle = actor:GetAngle()
                                        local targetAngle = Angle.FromVectors(Vector3.Forward, dirNorm)
                                        local maxRotationSpeed = math.rad(360) * args.delta
                                        local newAngle = Angle.RotateToward(currentAngle, targetAngle, maxRotationSpeed)
                                        actor:SetAngle(newAngle)
                                    end
                                end

                                local walkAnimation = isWater and AnimationState.SSwimNavigation or AnimationState.SUprightBasicNavigation

                                actor:SetBaseState(walkAnimation)
                                actor:SetInput(Action.MoveForward, 1)
                            end
                        else
                            local idleAnimation = isWater and AnimationState.SSwimIdle or AnimationState.SUprightIdle

                            actor:SetBaseState(idleAnimation)

                            if not actor:GetVehicle() then
                                local weapon = actor:GetEquippedWeapon()

                                if weapon and weapon.ammo_clip == 0 and weapon.ammo_reserve > 0 then
                                    data.isReloading = true
                                    Timer.SetTimeout(1000, function()
                                        if IsValid(actor) then
                                            data.isReloading = false
                                        end
                                    end)
                                    actor:SetUpperBodyState(AnimationState.UbSReloading)
                                    actor:SetInput(Action.Reload, 1)
                                elseif weapon then
                                    local targetPos = data.target:GetPosition()
                                    local dirToTarget = targetPos - actorPos

                                    dirToTarget.y = 0
                                    if dirToTarget:Length() > 0 then
                                        dirToTarget = dirToTarget:Normalized()
                                        local aimAngle = Angle.FromVectors(Vector3.Forward, dirToTarget)
                                        local maxRotationSpeed = math.rad(360) * args.delta
                                        local newAimAngle = Angle.RotateToward(actor:GetAngle(), aimAngle, maxRotationSpeed)
                                        local hasWeapon = actor:GetEquippedWeapon().id ~= 0

                                        if hasWeapon then actor:SetAngle(newAimAngle) end

                                        actor:SetAimPosition(data.target:GetBonePosition("ragdoll_Spine"))

                                        if not (data.isReloading or data.isHitReact) and IsValid(data.target) and
                                            data.target:GetHealth() > 0 then
                                            if hasWeapon then
                                                actor:SetUpperBodyState(AnimationState.UbSAiming)
                                                actor:SetInput(Action.FireRight, 1)
                                                actor:SetInput(Action.FireLeft, 1)
                                                actor:SetInput(Action.Fire, 1)
                                            end

                                            local resetFireTimer = data.resetFireTimer
                                            if resetFireTimer:GetSeconds() >= 1 then
                                                actor:ClearInput()
                                                resetFireTimer:Restart()
                                            end
                                        end
                                    end
                                end
                                isAiming = true
                            end
                        end

                        if not isAiming then
                            actor:SetUpperBodyState(AnimationState.UbSIdle)
                        end
                    end
                end
            end
        end
    end
end

function NPCAISystem:CreateActor(model_id, position, weapon)
    local actor = ClientActor.Create(AssetLocation.Game, {
        model_id = model_id,
        position = position,
        angle = Angle()
    })

    Timer.SetTimeout(1, function()
        if IsValid(actor) then
            actor:SetHealth(1)

            if weapon then
                if actor:GetEquippedWeapon() ~= Weapon(weapon) then
                    actor:GiveWeapon(1, Weapon(weapon, 99999, 99999))
                end
            end
        end
    end)

    return actor
end

function NPCAISystem:UpdateNPC(args)
    local id = args.id
    local target_id = args.target
    local target_player = (target_id == LocalPlayer:GetId()) and LocalPlayer or nil

    self.actors[id] = {target = target_player}
end

function NPCAISystem:CreateNPC(args)
    local id = args.id
    local pos = args.position
    local model = args.model
    local weapon = args.weapon
    local target_id = args.target
    local target_player = (target_id == LocalPlayer:GetId()) and LocalPlayer or nil

    if self.actors[id] then return end

    if not target_player then
        for player in Client:GetPlayers() do
            if player:GetId() == target_id then
                target_player = player
                break
            end
        end
    end

    local actor = self:CreateActor(model, pos, weapon)

    self.actors[id] = {
        actor = actor,
        target = target_player,
        waypoints = {},
        waypointIndex = 1,
        resetFireTimer = Timer(),
        lastPathUpdate = Timer()
    }

    ClientEffect.Play(AssetLocation.Game, {
        effect_id = 250,
        position = pos,
        angle = Angle()
    })
end

function NPCAISystem:SetWaypoints(args)
    local id = args.id
    local data = self.actors[id]

    if data then
        if args.waypointIndex then
            data.waypointIndex = args.waypointIndex
        end

        data.waypoints = args.waypoints
    end
end

function NPCAISystem:ActorDeath(data, id)
    if data and id then
        data.actor:SetHealth(0)
        data.actor:SetBaseState(AnimationState.SDead)
        data.actor:SetUpperBodyState(AnimationState.UbSIdle)

        Events:Fire("NPCDeath")

        data.death_timer = Timer.SetTimeout(10000, function() self:RemoveActor(id) end)
    end
end

function NPCAISystem:RemoveActor(id)
    local data = self.actors[id]

    if data and data.actor then
        data.actor:Remove()
    end

    self.actors[id] = nil
    Network:Send("RemoveNPC", id)
end

local npcaisystem = NPCAISystem()
-----------------------------------------------------------------------------------
--Script Version
--v0.1--

--Release Date
--11.09.25--
-----------------------------------------------------------------------------------