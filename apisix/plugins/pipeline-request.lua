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
local core   = require("apisix.core")
local http   = require("resty.http")
local pairs       = pairs


local schema = {
    type = "object",
    properties = {
        nodes = {
            type = "array",
            items = {
                type = "object",
                properties = {
                    uri = {
                        type = "string",
                        minLength = 1
                    },
                    timeout = {
                        type = "integer",
                        minimum = 1,
                        maximum = 60000,
                        default = 3000,
                        description = "timeout in milliseconds",
                    },
                },
                required = {"uri"},
            }
        },
    },
}

local plugin_name = "pipeline-request"

local _M = {
    version = 0.1,
    priority = 4011,
    name = plugin_name,
    schema = schema,
}


function _M.check_schema(conf)
    local ok, err = core.schema.check(schema, conf)
    if not ok then
        return false, err
    end

    return true
end


function _M.access(conf, ctx)
    if #conf.nodes <= 0 then
        return 500, "empty nodes"
    end

    local last_resp, err
    for _, value in ipairs(conf.nodes) do
        local httpc = http.new()
        httpc:set_timeout(value.timeout)

        local params = {
            method = "POST",
            ssl_verify = false,
        }

        if last_resp ~= nil then
            -- setup body from last success response
            params.method = "POST"
            params.body = last_resp.body
        else
            -- setup header, query and body for first request (upstream)
            params.method = core.request.get_method()
            params.headers = core.request.headers()
            params.query = core.request.get_uri_args()
            local body, err = core.request.get_body()
            if err then
                return 503
            end
            if body then
                params.body = body
            end
        end

        -- send request to each node and temporary store response
        last_resp, err = httpc:request_uri(value.uri, params)
        if not last_resp then
            return 500, "request failed" .. err
        end
    end

    -- send all headers from last_resp to client
    for key, value in pairs(last_resp.headers) do
        core.response.set_header(key, value)
    end

    return 200, last_resp.body
end


return _M
