local typesCache = require(script.Parent.typesCache)

local region = {}

function region.start(data: typesCache.RegionData): {Instance}?
    assert(data, `@paramter region data expected`)

    if data.ignore and data.include then
        error(`include and ignore cannot be defined together NERD`)
    end

    if data.ignore then
        local region = OverlapParams.new()
        region.BruteForceAllSlow = true
        region.FilterDescendantsInstances = data.ignore

        return workspace:GetPartBoundsInBox(data.from, data.to, region)
    end

    if data.include then
        local region = OverlapParams.new()
        region.BruteForceAllSlow = true
        region.FilterDescendantsInstances = data.ignore
        region.FilterType = Enum.RaycastFilterType.Include
        
        return workspace:GetPartBoundsInBox(data.from, data.to, region)
    end
    
    return nil
end

return region