--
-- request_handler.lua
--

local pgmoon = require("pgmoon")
local encode_json = require("pgmoon.json").encode_json
local url = require('net.url')
local redirected = false

local dbconn_params = {
  host = ngx.var.pgwt_conn_host,
  port = ngx.var.pgwt_conn_port,
  database = ngx.var.pgwt_conn_db,
  user = ngx.var.pgwt_conn_user,
  password = ngx.var.pgwt_conn_password
}

local args = nil;

if ngx.var.args ~= nil then
  args = url.parseQuery(ngx.var.args)
end

local request = {
  area = ngx.var.pgwt_area,
  host = ngx.var.host,
  path = ngx.var.path,
  method = ngx.req.get_method(),
  args = args,
  remote_addr = ngx.var.remote_addr,
  remote_host = ngx.var.rdns_hostname,
  server_host = ngx.var.pgwt_server_host,
  server_addr = ngx.var.server_addr,
  headers = ngx.req.get_headers(),
  is_internal = ngx.req.is_internal(),
  resp_headers = ngx.resp.get_headers(),
  status = ngx.var.status,
  body_bytes_sent = ngx.var.body_bytes_sent,
  request_completion = ngx.var.request_completion,
  request_body_file = ngx.var.request_body_file
}

local pg = pgmoon.new(dbconn_params)

assert(pg:connect())

if request.headers["content_type"] ~= nil and string.match(request.headers["content_type"], '^multipart/form%-data;') then
  --this is multipart form data
  if ngx.var.pgwt_read_multipart_body ~= nil and ngx.var.pgwt_read_multipart_body == 'true' then
    ngx.req.read_body()
  end
else
  ngx.req.read_body()
end

if ngx.var.pgwt_conn_host == nil or ngx.var.pgwt_conn_host == "false" then
  ngx.req.read_body()
end

local body
if ngx.var.request_body ~= nil then
  body = pg:escape_literal(ngx.var.request_body)
else
  body = "NULL"
end

local json_request = encode_json(request)
local res = assert(pg:query("select * from pgwt.request("..json_request..","..body..")"))
local row = res[1]
local commands = { }

pg:keepalive(60000, 10)

if row and
   row["status"] ~= pg.null and
   row["body"] ~= pg.null
then
  if row["diag"] ~= pg.null then
    local pg = pgmoon.new(dbconn_params)

    assert(pg:connect())

    assert(pg:query("select pgwt.api_error("
      .."a_uri := "..pg:escape_literal(ngx.var.path)..","
      .."a_diag := "..encode_json(row["diag"])..")"))

    pg:keepalive(60000, 10)
  end

  if ngx.var.status ~= "000" then
    -- this is post_action, nothing to do
    return
  end

  local ext_request_command

  ngx.status = row["status"]

  if row["headers"] ~= pg.null
  then
    headers = row["headers"]

    if headers ~= nil then
      for key,value in pairs(headers) do
        ngx.header[key] = value;
      end
    end
  end

  if row["commands"] ~= nil
  then
    commands = row["commands"]

    if commands ~= nil then
      if commands["limit_rate"] then
        ngx.var.limit_rate = commands["limit_rate"]
      end

      if commands["rewrite"] then        -- rewrite original request
        ngx.req.set_uri('/'..commands["rewrite"], false)
        return;
      end

      if commands["i-redirect"] then
        -- redirect to internal location
        ngx.req.set_uri(commands["i-redirect"], true)
        return;
      end

      if commands["e-redirect"] then
        -- redirect to external location
        ngx.redirect(commands["e-redirect"])
        return;
      end

      if commands["e-proxy-body"] then
        ngx.var.pgwt_proxy_body = commands["e-proxy-body"]
      end

      if commands["e-proxy"] then
        ngx.var.pgwt_proxy_url = commands["e-proxy"]
        return;
      end
    end
  end

  -- external request disabled
  if false and ext_request_command ~= nil
  then
    local uri = ext_request_command["uri"]
    local handler = ext_request_command["handler"]

    if uri == nil or handler == nil
    then
      -- bad ext_request_command format
      ngx.exit(500)
    end

    local resp = ngx.location.capture("/proxy",
      {
        method = ngx.HTTP_POST,
        vars = { proxy_uri = uri },
        body = row["body"]
      }
    )

    ngx.req.set_header("external-request-status", resp.status)
    ngx.req.set_header("external-request-headers", resp.headers)

    ngx.req.set_body_data(resp.body)
    ngx.req.set_uri("/i/"..handler, true)
  else
    if row["body"] ~= "" then
      if commands["decode-base64"] then
        ngx.print(ngx.decode_base64(row["body"]))
      else
        ngx.print(row["body"])
      end
    end

    ngx.exit(ngx.status)
  end
else
  -- bad database response
  ngx.exit(500)
end
