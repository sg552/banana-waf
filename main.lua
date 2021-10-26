
require 'method'

local function start()

  if white_ip_check() then
  elseif white_user_agent_and_length_check() then
  elseif black_ip_check() then
  elseif url_attack_check() then
  elseif url_args_attack_check() then
  elseif cookie_attack_check() then
  elseif user_agent_attack_check() then
    --判断某个url单位时间访问的限制
  elseif uri_frequency_check() then
  else
    return
  end

end
start()
