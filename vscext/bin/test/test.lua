local function func(...)
    local arg = {...}
    local idx = -1
    while true do
        local name, value = debug.getlocal(1, idx)
        if not name then break end
        print(name, value)
        idx = idx - 1
    end
    local c = 1
    local d = true
    local s = "abc"
    local t = {
        name = "time",
        age = 21,
        say = function()
            print("hello")
        end
    }
    print(t.name)
    return d
end

local function func_require()
    local test2 = require "test2"
    return test2
end

local function func_error()
    local function in_func()
        error("test error")
    end
    in_func()
    local a = "ok"
    local b = "yes"
    return a .. b
end

local function func_co()
    local function foo (a)
        print("foo", a)
        return coroutine.yield(2*a)
    end
    
    co = coroutine.create(function (a,b)
        print("co-body", a, b)
        local r = foo(a+1)
        print("co-body", r)
        local r, s = coroutine.yield(a+b, a-b)
        print("co-body", r, s)
        return b, "end"
    end)
    
    print("func_co", coroutine.resume(co, 1, 10))
    print("func_co", coroutine.resume(co, "r"))
    print("func_co", coroutine.resume(co, "x", "y"))
    print("func_co", coroutine.resume(co, "x", "y"))
end

local function func_co2()
    co = coroutine.create(function()
        print("co-body")
        error("co error")
        print("co-body2")
    end)
    local ok, msg = coroutine.resume(co)
    print(ok, msg)
end

local function func_cond()
    for i = 1, 5 do
        print(i)
    end
    local t = {
        name = "tom",
        age = 2,
        male = true,
    }
    for k, v in pairs(t) do
        print(k, v)
    end
end

local function entry()
    -- 普通函数调用
    func(10, 20, "hello", true)
    local a = 1
    local b = 2
    -- require脚本
    func_require()
    -- 测试错误 
    pcall(func_error)
    -- func_error()
    -- 测试协程调用
    func_co();
    -- 测试协程报错的情况
    func_co2();
    -- 测试条件断点
    func_cond();
end

print(...)
entry()
