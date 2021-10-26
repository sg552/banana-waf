-- 解析得到boundary
local function get_boundary(body_data)
    -- 解析body首行或者第二行，直到解析到--$boundary。若三行内都没解析到boundary，则视为异常。
    local first_position = string.find(body_data, "\n");
    local boundary = string.sub(body_data, 1, first_position)
    if not boundary then
      -- Todo 取第二行作为boundary
      --ngx.log(ngx.ERR, '第一行没有找到boundary')
    end
    return boundary
  end

  -- 字符串分隔得到数组
  local function explode ( _str, seperator)
      local pos, arr = 0, {}
      for st, sp in function() return string.find( _str, seperator, pos, true ) end do
        table.insert(arr, string.sub(_str, pos, st-1 ))
        pos = sp + 1
      end
      table.insert(arr, string.sub( _str, pos))
      return arr
  end
  -- unicode 解码
 local function unescape (s)
    s = string.gsub(s, "+", " ")
    s = string.gsub(s, "%%(%x%x)", function (h)
      return string.char(tonumber(h, 16))
    end)
    return s
end

function get_uri_args()
    -- 返回args
    local args = {}
    local receive_headers = ngx.req.get_headers()
    local request_method = ngx.var.request_method
    local error_code = 0
    local error_msg = "未初始化"

    if "GET" == request_method then
      -- 普通get请求
        args = ngx.req.get_uri_args()
      elseif "POST" == request_method then
        ngx.req.read_body()
        local con_type = receive_headers["content-type"]
        if con_type ~= nil and string.sub(con_type,1,20) == "multipart/form-data;" then--判断是否是multipart/form-data类型的表单
            local body_data = ngx.req.get_body_data()--body_data可是符合http协议的请求体，不是普通的字符串
            ngx.log(ngx.ERR, body_data)
            --请求体的size大于nginx配置里的client_body_buffer_size，则会导致请求体被缓冲到磁盘临时文件里，client_body_buffer_size默认是8k或者16k
            if not body_data then
              local datafile = ngx.req.get_body_file()
              if not datafile then
                    error_code = 1
                    error_msg = "no request body found"
                else
                    local fh, err = io.open(datafile, "r")
                    if not fh then
                        error_code = 2
                        error_msg = "failed to open " .. tostring(datafile) .. "for reading: " .. tostring(err)
                    else
                        fh:seek("set")
                        body_data = fh:read("*a")
                        fh:close()
                        if body_data == "" then
                            error_code = 3
                            error_msg = "request body is empty"
                        end
                    end
                end
            end
            --确保取到请求体的数据
            if error_code == 0 then
                local boundary = get_boundary(body_data)
                -- 兼容处理：当content-type中取不到boundary时，直接从body首行提取。
                local body_data_table = explode(tostring(body_data), boundary)
                for i,v in ipairs(body_data_table) do
                    local start_pos,end_pos,capture,capture2 = string.find(v,'Content%-Disposition: form%-data; name="(.+)"')
                    if start_pos ~= nil then
                      local t = explode(v,"\r\n\r\n")
                      local param_name_start_pos, param_name_end_pos, temp_param_name = string.find(t[1],'Content%-Disposition: form%-data; name="(.+)"')
                      local temp_param_value = string.sub(t[2],1,-3)
                      local value_table = explode(temp_param_value, '\n')
                      if value_table[1] ~= nil then
                        temp_param_value = value_table[1]
                        args[temp_param_name] = temp_param_value
                      end
                    end
                end
            end
        else
          -- 普通post请求
          args = ngx.req.get_post_args()
            --请求体的size大于nginx配置里的client_body_buffer_size，则会导致请求体被缓冲到磁盘临时文件里，client_body_buffer_size默认是8k或者16k
          --[[
            请求体的size大于nginx配置里的client_body_buffer_size，则会导致请求体被缓冲到磁盘临时文件里
            此时，get_post_args 无法获取参数时，需要从缓冲区文件中读取http报文。http报文遵循param1=value1&param2=value2的格式。
          ]]
          if not args then
              args = {}
              -- body_data可是符合http协议的请求体，不是普通的字符串
              local body_data = ngx.req.get_body_data()
              -- client_body_buffer_size默认是8k或者16k
              if not body_data then
                  local datafile = ngx.req.get_body_file()
                  if not datafile then
                      error_code = 1
                      error_msg = "no request body found"
                  else
                      local fh, err = io.open(datafile, "r")
                      if not fh then
                          error_code = 2
                          error_msg = "failed to open " .. tostring(datafile) .. "for reading: " .. tostring(err)
                      else
                          fh:seek("set")
                          body_data = fh:read("*a")
                          fh:close()
                          if body_data == "" then
                              error_code = 3
                              error_msg = "request body is empty"
                          end
                      end
                  end
              end
              -- 解析body_data
              local post_param_table = explode(tostring(body_data), "&")
              for i,v in ipairs(post_param_table) do
                  local paramEntity = explode(v,"=")
                  local tempValue = paramEntity[2]
                  -- 对请求参数的value进行unicode解码
                  tempValue = unescape(tempValue)
                  args[paramEntity[1]] = tempValue
              end
          end
        end
    end
    return args
end
