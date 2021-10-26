cache = true
std = 'ngx_lua'
ignore = {
    "_", -- 忽略 _ 变量，我们用它来表示没有用到的变量
    "6..", -- 忽略格式上的warning
}
-- 这里因为客观原因，定的比较松。如果条件允许，你可以去掉这些豁免条例。
unused = false
unused_args = false
unused_secondaries = false
redefined = false
-- top-level module name
globals = {
    -- 标记 ngx.header and ngx.status 是可以被写入的
    "ngx",
}

-- 不检查来自第三方的代码库
exclude_files = {
    "nginx/resty",
}
