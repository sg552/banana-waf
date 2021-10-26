# Banana Waf

BananaWaf是个超级简单但是实用的防火墙。与Openresty + Nginx集成，可以轻松防御绝大部分的恶意请求。
包括：

- SQLI
- XSS
- 恶意后缀扫描
- 恶意POC、参数
- 指定某个URL的访问频率
- 防止客户端使用F12
- 返回迷惑性的response, 可以定制(例如java项目返回php报错页面)

还具备一个管理后台，可以设置对应URL的访问频率

优点：
1. 超级快速集成
2. 访问速度在很弱的开发服务器达到9000每秒, 还没有进一步测试生产环境。（欢迎PR）
3. 具备优秀的管理后台，可以查看防御情况（对手IP，工具手段，参数）

## 安装

### 1 首先安装openresty环境

参考：[Ubuntu安装openresty步骤](https://openresty.org/cn/linux-packages.html)

Redis: 正常安装就好。

### 2 在nginx同级目录下  git clone

### 3 修改config.lua中redis配置

### 4 在conf/nginx.conf 引入
```
http {

# 关键代码  引入lua脚本
  access_by_lua_file lua/main.lua;

 # 实现监听f12功能的脚本 引入方式
  header_filter_by_lua_file lua/header_filter.lua;
  body_filter_by_lua_file lua/body_filter_f12.lua;

  server {
    listen       80;
    server_name  www.ttlove.top;
    location / {
      try_files $uri $uri/index.html $uri/ =404;
      default_type text/html;
    }
  }
}
```

## 说明

### 1, 限制uri访问次数
#### 假如需要对 http://www.ttlove.top/hello?a=1 进行限制 60s 访问 最多访问5次
需要按照下面这样设置
```
hset lua_/hello lua_max_times 5  //最多访问的次数
hset lua_/hello lua_unit_time 60 //单位时间
```
在redis存储的key值 为域名和参数`?`之前中间的全部内容

### 2. 黑名单

+ `lua_black_ips` 黑名单列表key 通过redis中集合(Set) 存储的

#### 添加ip到黑名单
```
sadd lua_blocked_ips ip
```
#### 从黑名单中删除
```
srem lua_blocked_ips ip
```


## 使用luacheck进行静态代码分析

### luacheck 安装
#### 1, apt install luarocks

#### 2, luarocks install luacheck

#### 3,新增`.luacheckrc`文件

luacheck 使用时会优先查找当前目录下的 `.luacheckrc` 文件，未找到则去上层目录查找，以此类推


> js文件中不要有任何的注释

redis 保持长连接 测试 结果
ab -n 10000 -c 100  http://127.0.0.1/

短连接：最高 5000多
长连接：最高9000

```
local ok, err = red:set_keepalive(10000, 100)
if not ok then
    ngx.say("failed to set keepalive: ", err)
    return
end
```





