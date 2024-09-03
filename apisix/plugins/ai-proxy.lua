--
-- Licensed to the Apache Software Foundation (ASF) under one or more
-- contributor license agreements.  See the NOTICE file distributed with
-- this work for additional information regarding copyright ownership.
-- The ASF licenses this file to You under the Apache License, Version 2.0
-- (the "License"); you may not use this file except in compliance with
-- the License.  You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
local core = require("apisix.core")
local schema = require("apisix.plugins.ai-proxy.schema")
local require = require
local pcall = pcall

local ngx_req = ngx.req

local plugin_name = "ai-proxy"
local _M = {
    version = 0.5,
    priority = 1004,
    name = plugin_name,
    schema = schema,
}


function _M.check_schema(conf)
    local ai_driver = pcall(require, "apisix.plugins.ai-proxy.drivers." .. conf.model.provider)
    if not ai_driver then
        return false, "provider: " .. conf.model.provider .. " is not supported."
    end
    return core.schema.check(schema.plugin_schema, conf)
end


local CONTENT_TYPE_JSON = "application/json"


function _M.access(conf, ctx)
    local route_type = conf.route_type
    ctx.ai_proxy = {}

    local ct = core.request.header(ctx, "Content-Type") or CONTENT_TYPE_JSON
    if not core.string.has_prefix(ct, CONTENT_TYPE_JSON) then
        return 400, "unsupported content-type: " .. ct
    end

    local request_table, err = core.request.get_request_body_table()
    if not request_table then
        return 400, err
    end

    local ok, err = core.schema.check(schema.chat_request_schema, request_table)
    if not ok then
        return 400, "request format doesn't match schema: " .. err
    end

    if conf.model.options and conf.model.options.stream then
        request_table.stream = true
        ctx.disable_proxy_buffering = true
    else
        ctx.subrequest = true
    end

    if conf.model.name then
        request_table.model = conf.model.name
    end

    local ai_driver = require("apisix.plugins.ai-proxy.drivers." .. conf.model.provider)
    -------------------------------- MODIFIED --------------------------------
    local res, err = ai_driver.request(conf, request_table, ctx)
    if not res then
        return 500, "failed to proxy LLM request: " .. err
    end

    local data

    if conf.passthrough then
        -- do we need a buffer to cache entire LLM response?
        -- i think so, we can do something like the following, just read, no return
        ngx_req.set_body_data(res.data)
        return
    end

    if core.table.try_read_attr(conf, "model", "options", "stream") then
        local reader = res.body_reader
        while true do
            local buffer, err = reader()
            if err then
                ngx.log(ngx.ERR, err)
                break
            end

            ngx.print(buffer)
            ngx.flush(true) -- just a example, need more verification
        end
    else
        return 200, res.data
    end
    -- we may have to simulate an SSE (chunked) response through the scheme mentioned in
    -- https://github.com/openresty/lua-nginx-module/issues/1736#issuecomment-650143112
    -- return 200, res.data
    --------------------------------------------------------------------------
end

return _M
