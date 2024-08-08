import logging, glob, time
import psutil

try:
  import pynvml as N
  logging.info("pynvml found, assuming NVIDIA GPU")
  try:
    N.nvmlInit()
    GPU_HANDLES = [N.nvmlDeviceGetHandleByIndex(i) for i in range(6)]
  except:
    logging.warning("Failed to find all 6 gpus")
    GPU_HANDLES = []
  def get_gpu_utilizations() -> list[float]:
    gpu_utilizations = []
    try:
      for handle in GPU_HANDLES:
        utilization = N.nvmlDeviceGetUtilizationRates(handle)
        gpu_utilizations.append(utilization.gpu)
    except:
      logging.warning("Failed to read GPU utilization")
      return []
    return gpu_utilizations
  total_vrams = [N.nvmlDeviceGetMemoryInfo(handle).total for handle in GPU_HANDLES]
  def get_gpu_memory_utilizations() -> list[float]:
    gpu_memory_utilizations = []
    try:
      for handle in GPU_HANDLES:
        memory = N.nvmlDeviceGetMemoryInfo(handle)
        gpu_memory_utilizations.append(memory.used / memory.total * 100)
    except:
      logging.warning("Failed to read GPU memory utilization")
      return []
    return gpu_memory_utilizations
  def get_gpu_power_draw() -> list[int]:
    gpu_power_draws = []
    try:
      for handle in GPU_HANDLES:
        power = N.nvmlDeviceGetPowerUsage(handle)
        gpu_power_draws.append(power // 1000)
    except:
      logging.warning("Failed to read GPU power draw")
      return []
    return gpu_power_draws
except ImportError:
  logging.info("pynvml not found, assuming AMD GPU")
  def get_gpu_utilizations() -> list[float]:
    gpu_utilizations = []
    try:
      for i in range(1, 7):
        with open(f"/sys/class/drm/card{i}/device/gpu_busy_percent", "r") as f:
          gpu_utilizations.append(int(f.read().strip()))
    except:
      logging.warning("Failed to read GPU utilization")
      return []
    return gpu_utilizations
  def get_gpu_memory_utilizations() -> list[float]:
    gpu_memory_utilizations = []
    try:
      for i in range(1, 7):
        with open(f"/sys/class/drm/card{i}/device/mem_info_vram_used", "r") as f:
          used = int(f.read().strip())
        with open(f"/sys/class/drm/card{i}/device/mem_info_vram_total", "r") as f:
          total = int(f.read().strip())
        gpu_memory_utilizations.append(used / total * 100)
    except:
      logging.warning("Failed to read GPU memory utilization")
      return []
    return gpu_memory_utilizations
  hwmon_paths = glob.glob("/sys/class/drm/card*/device/hwmon/hwmon*")
  def get_gpu_power_draw() -> list[int]:
    gpu_power_draws = []
    try:
      for path in hwmon_paths:
        with open(f"{path}/power1_average", "r") as f:
          gpu_power_draws.append(int(f.read().strip()) // 1000000)
    except:
      logging.warning("Failed to read GPU power draw")
      return []
    return gpu_power_draws

def get_cpu_utilizations() -> list[float]:
  try:
    return psutil.cpu_percent(percpu=True)
  except:
    logging.warning("Failed to read CPU utilization")
    return []

last_energy, last_energy_time = 0, time.monotonic()
def get_cpu_power_draw() -> int:
  global last_energy, last_energy_time
  try:
    with open("/sys/class/powercap/intel-rapl/intel-rapl:0/energy_uj", "r") as f:
      current_energy = int(f.read().strip())
    current_time = time.monotonic()
    power_draw = (current_energy - last_energy) / (current_time - last_energy_time) / 1e6
    if power_draw < 0:
      # energy counter rolled over
      power_draw = current_energy / (current_time - last_energy_time) / 1e6
    last_energy, last_energy_time = current_energy, current_time
    return int(power_draw)
  except:
    logging.warning("Failed to read CPU power draw")
    return 0

last_disk_read, last_disk_write, last_disk_time = 0, 0, time.monotonic()
def get_disk_io_per_second() -> tuple[int, int]:
  global last_disk_read, last_disk_write, last_disk_time
  counter = psutil.disk_io_counters(perdisk=True)["md0"]
  current_time = time.monotonic()
  disk_read = (counter.read_bytes - last_disk_read) / (current_time - last_disk_time)
  disk_write = (counter.write_bytes - last_disk_write) / (current_time - last_disk_time)
  last_disk_read, last_disk_write, last_disk_time = counter.read_bytes, counter.write_bytes, current_time
  return int(disk_read / 1e6), int(disk_write / 1e6)
