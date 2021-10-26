require 'lib'

--local content_type = content_type()
--ngx.log(ngx.ERR, '======= body_fileter_lua    get content_type ', content_type)
--if content_type ~= nil then
--  local loc, len = string.find(content_type, 'text/html')
--  if loc ~= nil then
--    ngx.log(ngx.ERR, '=======set content length is nil')
    ngx.header.content_length = nil
--  end
--end
