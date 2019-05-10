if onServer() then


local data = { wormHoleTimer = 0 }
local secondStageOfRemoval = false

function ActivateTeleport.initialize()
    Sector():registerCallback("onRestoredFromDisk", "onRestoredFromDisk")
end

function ActivateTeleport.updateServer(timePassed)
    -- if there's a wormhole, don't activate
    -- this is to prevent double activation
    local canSpawnWormhole = true
    local wormholes = {Sector():getEntitiesByComponent(ComponentType.EntityTransferrer)}
    local wormhole, wh, tx, ty
    for i = 1, #wormholes do
        wormhole = wormholes[i]
        if not wormhole:hasScript("data/scripts/entity/gate.lua") then -- Integration: Gate Founder
            if data.wormHoleTimer <= 0 or wormhole:hasComponent(ComponentType.DeletionTimer) then -- despawn wormhole
                --print("trying to remove wormhole to center")
                wh = wormhole:getWormholeComponent()
                tx, ty = wh:getTargetCoordinates()
                if not Galaxy():sectorLoaded(tx, ty) then
                    --print("loading sector to remove wormhole from it")
                    Galaxy():loadSector(tx, ty)
                end
                if not secondStageOfRemoval then
                    wh.oneWay = true
                    runRemoteSectorCode(tx, ty,
[[function removeWormholeFromCenter()
    for _, wormhole in pairs({Sector():getEntitiesByComponent(ComponentType.EntityTransferrer)}) do
        if not wormhole:hasScript("data/scripts/entity/gate.lua") then
            wormhole:getWormholeComponent().oneWay = true
            Sector():deleteEntity(wormhole)
        end
    end
end]], "removeWormholeFromCenter")
                else -- finally remove this wormhole
                    Sector():deleteEntity(wormhole)
                end
                secondStageOfRemoval = not secondStageOfRemoval
            end
            canSpawnWormhole = false
            break
        end
    end
    if not canSpawnWormhole then
        data.wormHoleTimer = data.wormHoleTimer - timePassed
        return
    end

    -- get all entities that can have upgrades
    local entities = {Sector():getEntitiesByComponent(ComponentType.ShipSystem)}

    -- filter out all entities that don't have a teleporter key upgrade
    for i, entity in pairs(entities) do
        if entity:hasScript("teleporterkey") == false then
            entities[i] = nil
        end
    end

    local teleporters = ActivateTeleport.getTeleporters()
    local teleportersOccupied = 0

    -- check if positioning is correct
    for i, teleporter in pairs(teleporters) do
        if valid(teleporter) then
            local occupied

            for _, entity in pairs(entities) do
                if teleporter.index ~= entity.index then
                    local scriptName = string.format("teleporterkey%i.lua", i)

                    if entity:hasScript(scriptName) then
                        local d = teleporter:getNearestDistance(entity)
                        if d <= activationDistance then
                            occupied = true
                            break
                        end
                    end
                end
            end

            if occupied then
                teleportersOccupied = teleportersOccupied + 1
            end
        end
    end

    if teleportersOccupied == 8 then
        ActivateTeleport.activate()
    end
end

function ActivateTeleport.activate()
    -- if yes, activate the wormhole
    local x, y = Sector():getCoordinates()
    local own = vec2(x, y)
    local d = length(own)

    local distanceInside = 5;

    -- find a free destination inside the ring
    local destination = nil
    while not destination do
        local d = own / d * (Balancing.BlockRingMin - distanceInside)

        local specs = SectorSpecifics()
        local target = specs:findFreeSector(random(), math.floor(d.x), math.floor(d.y), 1, distanceInside - 1, Server().seed)

        if target then
            destination = target
        else
            distanceInside = distanceInside + 1
        end
    end

    local desc = WormholeDescriptor()

    local cpwormhole = desc:getComponent(ComponentType.WormHole)
    cpwormhole.color = ColorRGB(1, 0, 0)
    cpwormhole:setTargetCoordinates(destination.x, destination.y)
    cpwormhole.visualSize = 100
    cpwormhole.passageSize = 150
    cpwormhole.oneWay = false

    local wormHole = Sector():createEntity(desc)

    data.wormHoleTimer = 35 * 60 -- open for 35 minutes

    if not spawned then
        spawned = true

        deferredCallback(6, "spawnEnemies", 3, 3)
        deferredCallback(30, "spawnEnemies", 5, 5)
        deferredCallback(60, "spawnEnemies", 3, 20)
        deferredCallback(90, "spawnEnemies", 2, 50)
    end
end

function ActivateTeleport.secure()
    return data
end

function ActivateTeleport.restore(_data)
    data = _data
    if not data.wormHoleTimer then
        data.wormHoleTimer = 0
    end
end

function ActivateTeleport.onRestoredFromDisk(timePassed)
    data.wormHoleTimer = math.max(0, data.wormHoleTimer - timePassed)
end


end