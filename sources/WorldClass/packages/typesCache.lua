export type Callback<t, v> = (t,v)->nil

export type Signals = {
    Connect: Callback<any, ...any>,
    Fire: Callback<any, ...any>,
    Await: Callback<any, nil>,
    Destroy: Callback<any, nil>,
    SetToJanitor: Callback<any, {}>
}

export type World = {
    packages: {},
}

export type RegionData = {
    from: Vector3,
    to: Vector3,
    
    ignore: {Instance},
    include: {Instance},
}

return  nil