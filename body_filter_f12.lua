require 'config'
require 'lib'

local content_type = get_resp_content_type()
if content_type == nil then
  return
end

--ngx.log(ngx.ERR, '============ content_type  is ', content_type)

local location, _ = string.find(content_type, 'text/html')
local json_location, _ = string.find(content_type, 'application')
local css_location, _ = string.find(content_type, 'text/css')

if location ~= nil or json_location ~= nil or css_location ~= nil then

  local chunk, eof = ngx.arg[1], ngx.arg[2]
  -- 定义全局变量，收集全部响应
  if ngx.ctx.buffered == nil then
    ngx.ctx.buffered = {}
  end

  -- 如果非最后一次响应，将当前响应赋值
  if chunk ~= "" and not ngx.is_subrequest then
    table.insert(ngx.ctx.buffered, chunk)
    -- 将当前响应赋值为空，以修改后的内容作为最终响应
    ngx.arg[1] = nil
  end

  -- 如果为最后一次响应，对所有响应数据进行处理
  if eof then
    -- 获取所有响应数据
    local whole = table.concat(ngx.ctx.buffered)
    if location  ~= nil then
      --获取whole里面是否有html 和 body标签  然后把js注入到</body>前面
      --因为返回的样式是这样的<!DOCTYPE html><html lang=en>  所以 改为判断 </html> </body>
      local html_location, _ = string.find(whole, '</html>')
      local body_location, _ = string.find(whole, '</body>')
      if html_location ~= nil and body_location ~= nil then
        ngx.ctx.buffered = nil
        local js = get_console_js()
        if js ~= '</body>' then
          whole = string.gsub(whole,'</body>',js, 1)
        end
      end
    end

    whole = replace_cdn(whole)

    ngx.arg[1] = whole
  end
end
