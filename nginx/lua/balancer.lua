local balancer = require "ngx.balancer"
local upstream = require "ngx.upstream"

local upstream_name = 'mysvr3'

local srvs = upstream.get_servers(upstream_name)

function is_down(server)
    local down = false
    local perrs = upstream.get_primary_peers(upstream_name)
    for i = 1, #perrs do
        local peer = perrs[i]
        if server == peer.name and peer.down == true then
            down = true
        end
    end
    return down
end

local remote_ip = ngx.var.remote_addr
local hash = ngx.crc32_long(remote_ip);
hash = (hash % 2) + 1
local backend = srvs[hash].addr
local index = string.find(backend, ':')
local host = string.sub(backend, 1, index - 1)
local port = string.sub(backend, index + 1)
ngx.log(ngx.DEBUG, "current peer ", host, ":", port)
balancer.set_current_peer(host, tonumber(port))
if not ok then
	ngx.log(ngx.ERR, "failed to set the current peer: ", err)
	return ngx.exit(500)
end
