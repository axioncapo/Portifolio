--!nocheck
--!nolint

local apollo = setmetatable({}, {
    __index = function(self)
        return "ApolloSignal"
    end
})

function apollo.new()
    local current = {
        callbacks = {},
        threads = {}
    }
    
    return current
end

function apollo:fire(...: any)
    for _, callback in self.callbacks do
        task.spawn(callback, ...)
    end

    for _, thread in self.threads do
        task.spawn(thread, ...)
    end
end

function apollo:await()
    assert(coroutine.isyieldable(), `running thread can't receive a yield`)

    local running = coroutine.running()

    table.insert(self.threads, running)

    return coroutine.yield()
end

function apollo:release()
    table.clear(self.threads)
    table.clear(self.callbacks)
    --//removing all strongs reff
    setmetatable(self, nil)
    self = nil
end

export type Signal<T...> = {
    connect: (self: any, callback:(T...)->())->(),
    fire: (self: any, callback: (T...)->())->(),
    await: (self: any)->T...,
    release: (self: any)->()
}

return apollo
