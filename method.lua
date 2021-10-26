require 'config'
require 'lib'
require 'get_params'

local cjson = require "cjson"
local redis = require "redis_iresty"
local rds = redis:new()
local rulematch = ngx.re.find
local unescape = ngx.unescape_uri


local function write_be_pulled_black_reason_to_redis(ip, reason, rule, match_value)
  --加入黑名单
  ngx.log(ngx.INFO, 'ip==', ip, '  reason=', reason, ' match_value=', match_value)
  rds:sadd(BLACKIPS_KEY, ip)
  --记录加入黑名单的原因MATCH_RULE: keyip { reason: value, commnet: connte, time: time}
  local reason_key = BLOCKED_REASON..ip
  local time = os.date("%Y-%m-%d %H:%M:%S")
  local comment = "MATCH_RULE:"..rule.."<br/>"..match_value.."<br/>".."URL:"..get_host_name()..get_uri().."<br/>"..get_user_agent().."<br/> method:"..get_request_method()
  rds:hset(reason_key, 'reason', reason)
  rds:hset(reason_key, 'comment', comment)
  rds:hset(reason_key, 'time', time)
end


function url_args_attack_check()
  local args_rules = get_rule('args.rule')
  local ip = get_client_ip()
  local req_args = get_uri_args()
  for _,rule in pairs(args_rules) do
    for key, val in pairs(req_args) do
      local args_data = val
      if type(val) == 'table' then
        args_data = table.concat(val, " ")
      end
      if args_data and type(args_data) ~= "boolean" and rule ~="" and rulematch(unescape(args_data),rule,"jo") then
        --ngx.log(ngx.INFO, '==== args not invalid Hacker Is Coming!!!!!!!!!!!!!!===',ip)
        write_be_pulled_black_reason_to_redis(ip, 'Illegal parameter', rule, "PARAMETER: "..key..'='..tostring(args_data))
        waf_output()
        return true
      end
    end
  end
  return false
end

function url_attack_check()
  local rules = get_rule('url.rule')
  local uri = get_uri()
  local ip = get_client_ip()
  for _,rule in pairs(rules) do
    if rule ~="" and rulematch(uri,rule,"jo") then
      --ngx.log(ngx.INFO, '=====url not invalid Hacker Is Coming!!!!!!!!!!!!!!===', ip)
      write_be_pulled_black_reason_to_redis(ip, 'Illegal url', rule, "URI: "..uri)
      waf_output()
      return true
    end
  end
  return false
end



function user_agent_attack_check()
  local user_agent_rules = get_rule('useragent.rule')
  local user_agent = get_user_agent()
  if user_agent ~= nil then
    local ip = get_client_ip()
    for _,rule in pairs(user_agent_rules) do
      if rule ~="" and rulematch(user_agent,rule,"jo") then
        --ngx.log(ngx.INFO, '=== useragent not invalid Hacker Is Coming!!!!!!!!!!!!!!')
        write_be_pulled_black_reason_to_redis(ip, 'Illegal user-agent', rule, "USER-AGENT:"..user_agent)
        waf_output()
        return true
      end
    end
  end
  return false
end

function cookie_attack_check()
  local cookie_rules = get_rule('cookie.rule')
  local user_cookie = ngx.var.http_cookie
  ngx.log(ngx.INFO, '---------------------------')
  ngx.log(ngx.INFO, user_cookie)
  if user_cookie ~= nil then
    local ip = get_client_ip()
    for _,rule in pairs(cookie_rules) do
      if rule ~="" and rulematch(user_cookie,rule,"jo") then
        ngx.log(ngx.INFO, '=== cookie not invalid Hacker Is Coming!!!!!!!!!!!!!!====', ip)
        write_be_pulled_black_reason_to_redis(ip, 'Illegal cookie', rule, "COOKIE: "..user_cookie)
        waf_output()
        return true
      end
    end
  end
  return false
end


function black_ip_check()
  local exists = rds:exists(BLACKIPS_KEY);
  if tonumber(exists) == 1 then
    local ip = get_client_ip()
    local host = get_host_name()
    ngx.log(ngx.ERR, '=================')
    ngx.log(ngx.ERR, '=========host====', host, '============')
    exists = rds:sismember(BLACKIPS_KEY,ip);
    if tonumber(exists) == 1 then
      ngx.log(ngx.INFO,"===== this is a blocked ip ===", ip);
      waf_output()
      return true;
    end
  end
  return false;
end

function white_ip_check()
  --ngx.log(ngx.ERR, 'is white ip')
  local exists = rds:exists(WHITE_KEY);
  if tonumber(exists) == 1 then
    local ip = get_client_ip()
    exists = rds:sismember(WHITE_KEY,ip);
    if tonumber(exists) == 1 then
      return true;
    end
  end
  return false
end

function white_user_agent_and_length_check()
  local exists = rds:exists(WHITE_USER_AGENT_KEY);
  local user_agent = get_user_agent()
  if tonumber(exists) == 1 then
    exists = rds:sismember(WHITE_USER_AGENT_KEY, user_agent);
    if tonumber(exists) == 1 then
      return true;
    end
  end
  if string.len(user_agent) < 6 then
    ngx.log(ngx.INFO, "user-agent 长度小于6 拉黑了")
    local ip = get_client_ip()
    write_be_pulled_black_reason_to_redis(ip, 'Illegal Length User-agent', '', user_agent)
    waf_output()
    return true
  end
  return false
end

function limit_ip_frequency(uri, times, time)
  local ip = get_client_ip()
  local rds_k = LIMITIPS_KEY.."_"..ip.."_"..uri
  local exists = rds:exists(rds_k);
  if tonumber(exists) == 0 then
    rds:zadd(rds_k,1,ip);
    rds:expire(rds_k, tonumber(time));
  else
    local count = rds:zscore(rds_k,ip);
    if count then
      if tonumber(count)  >= tonumber(times) then
        output_too_many_invite()
        return true;
      end
    end
    rds:zincrby(rds_k, 1,ip);
  end
  return false;
end

--记录用户行为
function record_user_behavior()
   --访问的uri ip useragent time params host request_headers
   local ip = get_client_ip()
   local params = get_uri_args()
   local time = os.date("%Y-%m-%d %H:%M:%S")
   local host = get_host_name()
   local req_headers = get_req_headers()
   local uri = get_uri()
   local http_method = get_request_method()
   local record = {
     ip = ip,
     params = params,
     time = time,
     host = host,
     req_headers = req_headers,
     http_method = http_method,
     number = math.random (),
     uri = uri
   }
   local json_data = cjson.encode(record)
   rds:sadd(RECORD_USER_BEHAVER, json_data)
end


function uri_frequency_check()
  local uri = get_uri()
  local pre_uri = "lua_"..uri
  local exists = rds:exists(pre_uri);
  if tonumber(exists) == 0 then
    return false
  else
    record_user_behavior()
    local times = 'lua_max_times'
    local time = 'lua_unit_time'
    local is_pre_uri_times_in_hash = rds:hexists(pre_uri, times)
    local is_pre_uri_time_in_hash = rds:hexists(pre_uri, time)

    if tonumber(is_pre_uri_times_in_hash) == 0 or tonumber(is_pre_uri_time_in_hash) == 0 then
      return false
    else
      local times = rds:hget(pre_uri, times)
      local time = rds:hget(pre_uri, time)
      return limit_ip_frequency(pre_uri, times, time)
    end
  end
end

