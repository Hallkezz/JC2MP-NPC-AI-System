---------------
--By Hallkezz--
---------------

-----------------------------------------------------------------------------------
--Usage (Server Events)
--Spawn NPC | Events:Fire("SpawnNPC", {target = <player id>, model = <number>, pos = <vector3>, weapon = <weapon>})
--Remove all NPCs | Events:Fire("RemoveAllNPCs")
-----------------------------------------------------------------------------------

-----------------------------------------------------------------------------------
--Script
class 'NPCAISystem'

function NPCAISystem:__init()
    self.actors = {}
    self.id_counter = 0
    self.timer = Timer()

    Events:Subscribe("SpawnNPC", self, self.SpawnNPC)
    Events:Subscribe("PlayerQuit", self, self.PlayerQuit)
    Events:Subscribe("RemoveAllNPCs", self, self.RemoveAllNPCs)
    Events:Subscribe("PostTick", self, self.PostTick)

    Network:Subscribe("UpdateNPCPosition", self, self.UpdateNPCPosition)
    Network:Subscribe("EntityBulletHit", self, self.EntityBulletHit)
    Network:Subscribe("VehicleCollide", self, self.VehicleCollide)
    Network:Subscribe("SetWaypoints", self, self.SetWaypoints)
    Network:Subscribe("RemoveNPC", self, self.RemoveNPC)
end

function NPCAISystem:UpdateNPCPosition(args)
    local id = args.id
    local pos = args.position
    local actors = self.actors[id]

    if actors then
        actors.position = pos
    end
end

function NPCAISystem:EntityBulletHit(args)
    local npc_id = args.id
    local damage = args.damage

    local data = self.actors[npc_id]
    if not data then return end

    data.health = (data.health or 1.0) - (damage / 100)

    if data.health <= 0 then
        Network:Broadcast("EntityDeath", npc_id)
        self.actors[npc_id] = nil
    else
        Network:Broadcast("EntityHitReact", {id = npc_id, health = data.health})
    end
end

function NPCAISystem:VehicleCollide(args, sender)
    local npc_id = args.id
    local speed = args.speed

    local data = self.actors[npc_id]
    if not data then
        return
    end

    if speed > 10 then
        Network:Broadcast("EntityDeath", npc_id)
        self.actors[npc_id] = nil
    end
end

function NPCAISystem:SpawnNPC(args)
    local npc_id = self.id_counter
    self.id_counter = self.id_counter + 1

    Network:Broadcast("CreateNPC", {
        id = npc_id,
        position = args.pos,
        model = args.model,
        weapon = args.weapon,
        target = args.target
    })

    self.actors[npc_id] = {
        position = args.pos,
        model = args.model,
        weapon = args.weapon,
        target = args.target
    }
end

function NPCAISystem:PostTick(args)
    if self.timer:GetSeconds() <= 1 then return end

    for npc_id, data in pairs(self.actors) do
        Network:Broadcast("CreateNPC", {
            id = npc_id,
            position = data.position,
            model = data.model,
            weapon = data.weapon,
            target = data.target
        })
    end

    self.timer:Restart()
end

function NPCAISystem:PlayerQuit(args)
    local player = args.player

    for id, data in pairs(self.actors) do
        if data.target == player:GetId() then
            Network:Broadcast("RemoveActor", id)
        end
    end
end

function NPCAISystem:SetWaypoints(args)
    local npc_id = args.id
    local actors = self.actors[npc_id]

    if actors then
        actors.waypoints = args.waypoints
        actors.waypointIndex = args.waypointIndex

        Network:Broadcast("SetWaypoints", {
            id = npc_id,
            waypoints = args.waypoints,
            waypointIndex = args.waypointIndex,
            target = actors.target
        })
    end
end

function NPCAISystem:RemoveNPC(id)
    if self.actors[id] then
        self.actors[id] = nil
    end
end

function NPCAISystem:RemoveAllNPCs()
    for id in pairs(self.actors) do
        Network:Broadcast("RemoveActor", id)
        self.actors[id] = nil
    end
end

local npcaisystem = NPCAISystem()
-----------------------------------------------------------------------------------
--Script Version
--v0.1--

--Release Date
--11.09.25--
-----------------------------------------------------------------------------------