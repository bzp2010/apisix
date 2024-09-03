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
local _M = {}

local core = require("apisix.core")
local http = require("resty.http")
local test_scheme = os.getenv("AI_PROXY_TEST_SCHEME")
local upstream = require("apisix.upstream")
local ngx = ngx
local pairs = pairs

-- globals
local DEFAULT_ENDPOINT = "https://api.openai.com:443"
local DEFAULT_HOST = "api.openai.com"
local DEFAULT_PORT = 443

local path_mapper = {
    ["llm/chat"] = "/v1/chat/completions",
}

-------------------------------- MODIFIED --------------------------------
function _M.request(conf, request_table, ctx)
    local params = {
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json",
        },
        --keepalive = conf.keepalive,
        --ssl_verify = conf.ssl_verify
    }

    --if conf.keepalive then
    --    params.keepalive_timeout = conf.keepalive_timeout
    --    params.keepalive_pool = conf.keepalive_pool
    --end

    if conf.auth.type == "header" then
        -- move to headers table input
        params.headers[conf.auth.name] = conf.auth.value
    end

    if conf.model.options then
        for opt, val in pairs(conf.model.options) do
            request_table[opt] = val
        end
    end
    params.body = core.json.encode(request_table)

    local endpoint = DEFAULT_ENDPOINT .. path_mapper[conf.route_type]
    local httpc = http.new()
    --httpc:set_timeout(conf.timeout)

    return httpc:request_uri(endpoint, params)
end
--------------------------------------------------------------------------


return _M
