BACKEND_URL = "http://127.0.0.1:7776"

RELAY_HEADERS_TO_CLIENT = {
  "Access-Control-Allow-Origin",
  "Cache-Control",
  "Connection",
  "Content-Type",
  "Last-Modified",
  "Referrer-Policy",
}

MEM = unix.mapshared(8000 * 8)
LOCK = 0
function Lock()
  local ok, old = MEM:cmpxchg(LOCK, 0, 1)
  if not ok then
    if old == 1 then
      old = MEM:xchg(LOCK, 2)
    end
    while old > 0 do
      MEM:wait(LOCK, 2)
      old = MEM:xchg(LOCK, 2)
    end
  end
end

function Unlock()
  local old = MEM:fetch_add(LOCK, -1)
  if old == 2 then
    MEM:store(LOCK, 0)
    MEM:wake(LOCK, 1)
  end
end

BACKEND_PID = 1
LAST_BACKEND_USE = 2

local function startBackend()
  -- start up the backend server if it's not already running
  Lock()
  MEM:store(LAST_BACKEND_USE, GetTime())
  local pid = MEM:load(BACKEND_PID)
  if pid == 0 then
    pid = unix.fork()
    if pid == 0 then
      local python_prog = assert(unix.commandv("python3"))

      -- read environment variables from /etc/tinychat.env
      local env = {}
      local f = assert(io.open("/etc/tinychat.env", "r"))
      for line in f:lines() do
        local key, value = string.match(line, "([^=]+)=(.*)")
        table.insert(env, key .. "=" .. value)
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
    else
      MEM:store(BACKEND_PID, pid)
    end
  end
  Unlock()
end

function OnServerHeartbeat()
  Lock()
  local pid = MEM:load(BACKEND_PID)
  if pid ~= 0 then
    local last_time = MEM:load(LAST_BACKEND_USE)
    if GetTime() - last_time > 5 * 60 then
      Log(kLogInfo, "killing backend server")
      unix.kill(pid, unix.SIGTERM)
      MEM:store(BACKEND_PID, 0)
    end
  end
  Unlock()
end

function OnHttpRequest()
  local path = GetPath()
  Log(kLogInfo, "path: %s" % { path })

  -- forward all /v1 paths to the backend server
  if string.match(path, "^/v1/") then
    Lock()
    MEM:store(LAST_BACKEND_USE, GetTime())
    Unlock()

    -- if this is a completion request, start the backend server if it's not already running
    if string.match(path, "^/v1/chat/completions") then
      startBackend()
    end

    -- redirect the request to the backend server
    SetStatus(308)
    SetHeader("Location", "http://" .. GetHost() .. ":7776" .. path)
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
    elseif path == "/ctrl/status" then
      if BACKEND_PID then
        SetStatus(200)
        Write("ok")
      else
        SetStatus(503)
        Write("ok")
      end
    end
  else
    if path == "/" then
      path = "/index.html"
    end
    ServeAsset(path)
  end
end
