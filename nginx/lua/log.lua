local ctx = ngx.ctx
local lim = ctx.limit_conn
if lim then
	local key = ctx.limit_conn_key

	local conn, err = lim:leaving(key, 0.1)
	if not conn then
		ngx.log(ngx.ERR,
				"failed to record the connection leaving ",
				"request: ", err)
		return
	end
end
