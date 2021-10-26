require 'config'
--Get the client IP
--
-- 注意: 本方法在实际环境中,需要根据防火墙的文档进行修改,
-- 例如, 知道创宇,需要 header中的 HTTP_X_CONNECTING_IP
-- 注意: 这里需要小写,而且是 : x-connecting-ip
--
-- 实际nginx log中: $remote_addr $http_x_connecting_ip
function get_client_ip()
    -- 第一步, 获得知道创宇检测到的ip地址
    local client_ip = ngx.req.get_headers()["x-connecting-ip"]
    -- 第二步, 如果前面的是空,那么就获得 remote_addr, 该情况适用于: robot等内部局域网的机器(绕过了知道创宇防火墙)
    -- 真实情况下,不会发生 这个情况
    if client_ip == nil then
        client_ip = ngx.var.remote_addr
    end
    if client_ip == nil then
        client_ip  = "unknown"
    end
    return client_ip
end

--Get the client user agent
function get_user_agent()
    local user_agent = ngx.var.http_user_agent
    if user_agent == nil then
       user_agent = "unknown"
    end
    return user_agent
end

--获取请求的uri
function get_uri()
  return ngx.var.uri
end


--获取rules文件内容
function get_rule(rulefilename)
    local io = require 'io'
    local RULE_PATH = config_rule_dir
    local RULE_FILE = io.open(RULE_PATH..'/'..rulefilename,"r")
    if RULE_FILE == nil then
        return
    end
    local RULE_TABLE = {}
    for line in RULE_FILE:lines() do
        table.insert(RULE_TABLE,line)
    end
    RULE_FILE:close()
    return(RULE_TABLE)
end


--访问次数过多 返回的内容
function output_too_many_invite()
  ngx.header.content_type = "application/json; charset=utf-8"
  ngx.status = ngx.HTTP_OK
  ngx.say(config_too_many_invite)
  ngx.exit(ngx.status)
end

--自定义输出内容
function waf_output()
    if config_waf_output == "redirect" then
        ngx.redirect(config_waf_redirect_url, 301)
    else
        ngx.header.content_type = "text/html"
        ngx.status = ngx.HTTP_FORBIDDEN
        ngx.say(config_output_html)
        ngx.exit(ngx.status)
    end
end

--获取请求体 的content_type
function get_resp_content_type()
  return ngx.resp.get_headers()['content-type']
end


--获取请求方式 GET POST 等
function get_request_method()
   return ngx.var.request_method
end

--获取请求host
function get_host_name()
  return ngx.var.host
end

--获取请求头
function get_req_headers()
   return ngx.req.get_headers()
end

--获取监听f12的js内容
function get_console_js()
   local io = require 'io'
   local js_path = config_js_dir
   local js_file = io.open(js_path..'/monitor_console.js', "r")
   if js_file == nil then
     return '</body>'
   end
   local console_content = ''
   for line in js_file:lines() do
     console_content = console_content..line
   end
   console_content  = console_content..'</body>'
   return console_content
end

--自定义打印
function Logger(target)
  if target ~= nil then
    if type(target) == 'string' then
      ngx.log(ngx.ERR,'\n***value*****:   ', target, '\n')
    elseif type(target) == 'table' then
      for key, value in pairs(target) do
        ngx.log(ngx.ERR, '\n*****key:', key)
        Logger(value)
      end
    else
      ngx.log(ngx.ERR, type(target))
    end
  end
end

function replace_cdn(content)
  --content = string.gsub(content, 'https://showmethemoney.yijiayinshi.com', 'target_url')
  return content
end
