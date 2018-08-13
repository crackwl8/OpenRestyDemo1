local limit_conn = require "resty.limit.conn"

-- 对于内部重定向或子请求，不进行限制。因为这些并不是真正对外的请求。
if ngx.req.is_internal() then
    return
end

-- 限制一个 ip 客户端最大 5 个并发请求
-- burst 设置为 0，如果超过最大的并发请求数，则直接返回503，
-- 如果此处要允许突增的并发数，可以修改 burst 的值（漏桶的桶容量）
-- 最后一个参数其实是你要预估这些并发（或者说单个请求）要处理多久，以便于对桶里面的请求应用漏桶算法
local lim, err = limit_conn.new("my_limit_conn_store", 5, 5, 0.1)              
if not lim then
	ngx.log(ngx.ERR, "failed to instantiate a resty.limit.conn object: ", err)
	return ngx.exit(500)
end

local key = ngx.var.binary_remote_addr
-- commit 为true 代表要更新shared dict中key的值，
-- false 代表只是查看当前请求要处理的延时情况和前面还未被处理的请求数
local delay, err = lim:incoming(key, true)
if not delay then
	if err == "rejected" then
		return ngx.exit(503)
	end
	ngx.log(ngx.ERR, "failed to limit req: ", err)
	return ngx.exit(500)
end

-- 如果请求连接计数等信息被加到shared dict中，则在ctx中记录下，
-- 因为后面要告知连接断开，以处理其他连接
if lim:is_committed() then
	local ctx = ngx.ctx
	ctx.limit_conn = lim
	ctx.limit_conn_key = key
	ctx.limit_conn_delay = delay
end

local conn = err
-- 其实这里的 delay 肯定是上面说的并发处理时间的整数倍，
-- 举个例子，每秒处理100并发，桶容量200个，当时同时来500个并发，则200个拒掉
-- 100个在被处理，然后200个进入桶中暂存，被暂存的这200个连接中，0-100个连接其实应该延后0.5秒处理，
-- 101-200个则应该延后0.5*2=1秒处理（0.5是上面预估的并发处理时间）
if delay >= 0.001 then
	ngx.sleep(delay)
end