local limit_req = require "resty.limit.req"

-- 限制请求速率为10 req/sec，并且允许5 req/sec的突发请求
local lim, err = limit_req.new("my_limit_req_store", 10, 5)
if not lim then
	ngx.log(ngx.ERR, "failed to instantiate a resty.limit.req object: ", err)
	return ngx.exit(500)
end

-- 使用ip地址作为限流的key，在有代理或cdn情况下binary_remote_addr不是真实ip，需要处理。
-- 还可以使用host、useragent等标识作为key来实现更宽或更细粒度的限速
local key = ngx.var.binary_remote_addr
local delay, err = lim:incoming(key, true)
if not delay then
	if err == "rejected" then
		return ngx.exit(503)
	end
	ngx.log(ngx.ERR, "failed to limit req: ", err)
	return ngx.exit(500)
end

if delay > 0 then
	-- 第二个参数(err)保存着超过请求速率的请求数
	local excess = err
	ngx.sleep(delay) --非阻塞sleep(秒)
end