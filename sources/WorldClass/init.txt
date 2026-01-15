local EncapsulatedMethods = {
    IsA = function(self, target_type: string)
        local dominant_name = self.__type
        assert(dominant_name, `Dominant class dont contain type for debug or something else, {self.__class_name} {debug.traceback(2)}`)
        
        return dominant_name == target_type 
    end;
    
    Extends = function(self, target)
        assert(target and typeof(target) == "table", `expected table as target, got {typeof(target)}`)

        self._prototypes[target.__class_name] = target
    end
}

local WorldClass = {Packages = script.packages}

WorldClass.__index = function(self, index: string)
    local result = EncapsulatedMethods[index] or self._prototypes[index]
    assert(result, `@index: {index} not finded on {self.__class_name}`)

    return result
end

WorldClass.__newindex = function(self, valueName: string, value)
    if valueName == "constructor" and type(value) ~= "function" then
        error(`Something went wrong, expected function as constructor, got {typeof(value)}`)
    end

    print("created new value", valueName, value)
    rawset(self, valueName, value)
end

function WorldClass.Class(class_name: string, class_type: string)
    assert(class_name, `@paramter expected(class_name), result {class_name}`)
    assert(class_type, `@paramter expected(class_type), result {class_type}`)

    local class = setmetatable({
        __type = class_type,
        __class_name = class_name,
        __is_paused = false,
        _prototypes = {}
    }, WorldClass)
    
    return class :: Object<any>
end

function WorldClass.new(classRef)
    assert(classRef, `ClassRef expected`)
    assert(classRef.constructor, `@property not setted, {classRef.constructor}`)
    
    if classRef.__is_paused then --//you can pause all classRefes, idk why i made that
        return coroutine.yield()
    end
    
    local this = setmetatable({}, {__index = classRef})

    classRef.constructor(this)
    
    return  this :: typeof(classRef)
end

export type ObjectMethods<T> = {
    IsA: (T, typeName: string)-> boolean,
    Extends: (T, target: {})-> T,
}

export type Object<T> = ObjectMethods<T> & {
    __type: string,
    __class_name: string,
    __is_paused: boolean,
    constructor: (...any)->(T)
}

return WorldClass