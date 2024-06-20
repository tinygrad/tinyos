BACKEND_URL = "http://127.0.0.1:7776"

RELAY_HEADERS_TO_CLIENT = {
  "Access-Control-Allow-Origin",
  "Cache-Control",
  "Connection",
  "Content-Type",
  "Last-Modified",
  "Referrer-Policy",
}

BACKEND_PID = nil
LAST_BACKEND_USE = 0

local function startBackend()
  -- start up the backend server if it's not already running
  if not BACKEND_PID then
    BACKEND_PID = unix.fork()
    if BACKEND_PID == 0 then
      local python_prog = assert(unix.commandv("python3"))

      -- read environment variables from /etc/tinychat.env
      local env = {}
      local f = assert(io.open("/etc/tinychat.env", "r"))
      for line in f:lines() do
        local key, value = string.match(line, "([^=]+)=(.*)")
        print("setting env", key, value)
        env[key] = value
      end

      unix.execve(python_prog, {
        python_prog,
        "/opt/tinybox/tinygrad/examples/llama3.py",
        "--model",
        "/raid/weights/LLaMA-3/8B-SF-DPO/model.safetensors.index.json",
        "--size",
        "8B",
        "--shard",
        "4",
      }, env)
    end
  end
end

function OnServerHeartbeat()
  if BACKEND_PID then
    if GetTime() - LAST_BACKEND_USE > 5 * 60 then
      Log(kLogInfo, "killing backend server")
      unix.kill(BACKEND_PID, unix.SIGTERM)
      BACKEND_PID = nil
    end
  end
end

function OnHttpRequest()
  local path = GetPath()
  Log(kLogInfo, "path: %s" % { path })

  -- forward all /v1 paths to the backend server
  if string.match(path, "^/v1/") then
    LAST_BACKEND_USE = GetTime()

    -- if this is a completion request, start the backend server if it's not already running
    if string.match(path, "^/v1/chat/completions") then
      startBackend()
    end

    -- redirect the request to the backend server
    SetStatus(301)
    SetHeader("Location", BACKEND_URL .. path)
  elseif string.match(path, "^/ctrl/") then
    -- control endpoints
    if path == "/ctrl/start" then
      startBackend()
      SetStatus(200)
      Write("ok")
    elseif path == "/ctrl/stop" then
      if BACKEND_PID then
        unix.kill(BACKEND_PID, unix.SIGTERM)
        BACKEND_PID = nil
      end
      SetStatus(200)
      Write("ok")
    end
  else
    if path == "/" then
      path = "/index.html"
    end
    ServeAsset(path)
  end
end
