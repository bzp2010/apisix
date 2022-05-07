#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
use t::APISIX 'no_plan';

repeat_each(1);
no_long_string();
no_root_location();

add_block_preprocessor(sub {
    my ($block) = @_;

    if ((!defined $block->error_log) && (!defined $block->no_error_log)) {
        $block->set_value("no_error_log", "[error]");
    }

    if (!defined $block->request) {
        $block->set_value("request", "GET /t");
    }
});

run_tests();

__DATA__

=== TEST 1: success
--- config
    location /t {
        content_by_lua_block {
            local t = require("lib.test_admin")
            local code, body = t.test("/apisix/admin/upstreams/kafka", ngx.HTTP_PUT, [[{
                "nodes": {
                    "127.0.0.1:9092": 1
                },
                "type": "none",
                "scheme": "kafka"
            }]])

            ngx.say(code..body)
        }
    }
--- response_body
201passed



=== TEST 2: success with tls
--- config
    location /t {
        content_by_lua_block {
            local t = require("lib.test_admin")
            local code, body = t.test("/apisix/admin/upstreams/kafka-tls", ngx.HTTP_PUT, [[{
                "nodes": {
                    "127.0.0.1:9092": 1
                },
                "type": "none",
                "scheme": "kafka",
                "tls": {
                    "verify": true
                }
            }]])

            ngx.say(code..body)
        }
    }
--- response_body
201passed



=== TEST 3: wrong tls verify type
--- config
    location /t {
        content_by_lua_block {
            local t = require("lib.test_admin")
            local code, body = t.test("/apisix/admin/upstreams/kafka-tls-error-type", ngx.HTTP_PUT, [[{
                "nodes": {
                    "127.0.0.1:9092": 1
                },
                "type": "none",
                "scheme": "kafka",
                "tls": {
                    "verify": "none"
                }
            }]])

            ngx.print(code..body)
        }
    }
--- response_body
400{"error_msg":"invalid configuration: property \"tls\" validation failed: property \"verify\" validation failed: wrong type: expected boolean, got string"}
