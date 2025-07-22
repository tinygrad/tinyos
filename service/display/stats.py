import glob, time, importlib, sys, logging
import psutil
from abc import ABC, abstractmethod

class GPUStats(ABC):
  def __init__(self, interval:float=0):
    self.interval = interval
    self.last_gpu_utilizations = []
    self.last_gpu_memory_utilizations = []
    self.last_gpu_power_draw = []
    self.last_gpu_utilizations_time = time.monotonic()
    self.last_gpu_memory_utilizations_time = time.monotonic()
    self.last_gpu_power_draw_time = time.monotonic()

  @abstractmethod
  def _get_gpu_count(self) -> int:
    pass

  @abstractmethod
  def _get_gpu_utilizations(self) -> list[float]:
    pass

  @abstractmethod
  def _get_gpu_memory_utilizations(self) -> list[float]:
    pass

  @abstractmethod
  def _get_gpu_power_draw(self) -> list[int]:
    pass

  def get_gpu_count(self) -> int:
    return self._get_gpu_count()

  def get_gpu_utilizations(self) -> list[float]:
    if self.interval > 0 and time.monotonic() - self.last_gpu_utilizations_time < self.interval:
      return self.last_gpu_utilizations
    self.last_gpu_utilizations = self._get_gpu_utilizations()
    self.last_gpu_utilizations_time = time.monotonic()
    return self.last_gpu_utilizations

  def get_gpu_memory_utilizations(self) -> list[float]:
    if self.interval > 0 and time.monotonic() - self.last_gpu_memory_utilizations_time < self.interval:
      return self.last_gpu_memory_utilizations
    self.last_gpu_memory_utilizations = self._get_gpu_memory_utilizations()
    self.last_gpu_memory_utilizations_time = time.monotonic()
    return self.last_gpu_memory_utilizations

  def get_gpu_power_draw(self) -> list[int]:
    if self.interval > 0 and time.monotonic() - self.last_gpu_power_draw_time < self.interval:
      return self.last_gpu_power_draw
    self.last_gpu_power_draw = self._get_gpu_power_draw()
    self.last_gpu_power_draw_time = time.monotonic()
    return self.last_gpu_power_draw

class NVGPUStats(GPUStats):
  def __init__(self):
    super().__init__()
    self.N = importlib.import_module("pynvml")
    self.N.nvmlInit()
    self.handles = [self.N.nvmlDeviceGetHandleByIndex(i) for i in range(self.get_gpu_count())]

  def _get_gpu_count(self) -> int:
    return self.N.nvmlDeviceGetCount()

  def _get_gpu_utilizations(self) -> list[float]:
    gpu_utilizations = []
    for handle in self.handles:
      utilization = self.N.nvmlDeviceGetUtilizationRates(handle)
      gpu_utilizations.append(utilization.gpu)
    return gpu_utilizations

  def _get_gpu_memory_utilizations(self) -> list[float]:
    gpu_memory_utilizations = []
    for handle in self.handles:
      memory = self.N.nvmlDeviceGetMemoryInfo(handle)
      gpu_memory_utilizations.append(memory.used / memory.total * 100)
    return gpu_memory_utilizations

  def _get_gpu_power_draw(self) -> list[int]:
    gpu_power_draws = []
    for handle in self.handles:
      power = self.N.nvmlDeviceGetPowerUsage(handle)
      gpu_power_draws.append(power // 1000)
    return gpu_power_draws

class AMDGPUStats(GPUStats):
  def __init__(self):
    super().__init__(interval=1)
    self.gpu_count = self.get_gpu_count()
    if self.gpu_count == 0:
      raise Exception("No AMD GPUs found")
    self.hwmon_paths = glob.glob("/sys/class/drm/card*/device/hwmon/hwmon*")

  def _get_gpu_count(self) -> int:
    gpus = 0
    for i in range(1, 7):
      try:
        with open(f"/sys/class/drm/card{i}/device/uevent", "r") as f:
          if "amdgpu" in f.read(): gpus += 1
      except:
        pass
    return gpus

  def _get_gpu_utilizations(self) -> list[float]:
    gpu_utilizations = []
    for i in range(1, self.gpu_count + 1):
      try:
        with open(f"/sys/class/drm/card{i}/device/gpu_busy_percent", "r") as f:
          gpu_utilizations.append(int(f.read().strip()))
      except:
        gpu_utilizations.append(0)
    return gpu_utilizations

  def _get_gpu_memory_utilizations(self) -> list[float]:
    gpu_memory_utilizations = []
    for i in range(1, self.gpu_count + 1):
      try:
        with open(f"/sys/class/drm/card{i}/device/mem_info_vram_used", "r") as f:
          used = int(f.read().strip())
        with open(f"/sys/class/drm/card{i}/device/mem_info_vram_total", "r") as f:
          total = int(f.read().strip())
        gpu_memory_utilizations.append(used / total * 100)
      except:
        gpu_memory_utilizations.append(0)
    return gpu_memory_utilizations

  def _get_gpu_power_draw(self) -> list[int]:
    gpu_power_draws = []
    for path in self.hwmon_paths:
      try:
        with open(f"{path}/power1_average", "r") as f:
          gpu_power_draws.append(int(f.read().strip()) // 1000000)
      except:
        gpu_power_draws.append(0)
    return gpu_power_draws

class AMGPUStats(GPUStats):
  def __init__(self):
    super().__init__()
    sys.path.insert(0, "/opt/tinybox/tinygrad/extra/amdpci/")
    sys.path.insert(0, "/opt/tinybox/tinygrad/")
    from am_smi import SMICtx

    self.ctx = SMICtx()
    self._refresh()

  def _refresh(self):
    self.ctx.rescan_devs()
    self.metrics = self.ctx.collect()

  def _get_gpu_count(self) -> int:
    return len(self.metrics)

  def _get_gpu_utilizations(self) -> list[float]:
    self._refresh()

    gpu_utilizations = []
    for dev, metrics in self.metrics.items():
      if dev.pci_state != "D0":
        gpu_utilizations.append(0)
      else:
        util = self.ctx.get_gfx_activity(dev, metrics)
        # remap util from 5-100 to 0-100
        gpu_utilizations.append((max(util - 5, 0) / (100 - 5)) * 100)
    return gpu_utilizations

  def _get_gpu_memory_utilizations(self) -> list[float]:
    gpu_memory_utilizations = []
    for dev, metrics in self.metrics.items():
      if dev.pci_state != "D0":
        gpu_memory_utilizations.append(0)
      else:
        mem_used = self.ctx.get_mem_usage(dev)
        mem_total = dev.vram_size
        gpu_memory_utilizations.append(mem_used / mem_total * 100)
    return gpu_memory_utilizations

  def _get_gpu_power_draw(self) -> list[int]:
    gpu_power_draws = []
    for dev, metrics in self.metrics.items():
      if dev.pci_state != "D0":
        gpu_power_draws.append(0)
      else:
        gpu_power_draws.append(self.ctx.get_power(dev, metrics)[0])
    return gpu_power_draws

class NULLGPUStats(GPUStats):
  def __init__(self):
    super().__init__()

  def _get_gpu_count(self) -> int:
    return 0

  def _get_gpu_utilizations(self) -> list[float]:
    return []

  def _get_gpu_memory_utilizations(self) -> list[float]:
    return []

  def _get_gpu_power_draw(self) -> list[int]:
    return []

class Stats:
  def __init__(self):
    self._init_gpu()
    self.last_energy, self.last_energy_time = 0, time.monotonic()
    self.last_disk_read, self.last_disk_write, self.last_disk_time = 0, 0, time.monotonic()
    self.last_gpu_init = time.monotonic()

  def _init_gpu(self):
    logging.info("initializing gpu stats")
    self.last_gpu_init = time.monotonic()
    self._gpu = NULLGPUStats()
    try:
      self._gpu = NVGPUStats()
    except:
      pass
    if self._gpu.get_gpu_count() != 0:
      logging.info(f"found {self._gpu.get_gpu_count()} NVIDIA GPUs")
      return
    try:
      self._gpu = AMDGPUStats()
    except:
      pass
    if self._gpu.get_gpu_count() != 0:
      logging.info(f"found {self._gpu.get_gpu_count()} AMD GPUs")
      return
    # try:
    #   self._gpu = AMGPUStats()
    # except:
    #   pass
    # if self._gpu.get_gpu_count() != 0:
    #   logging.info(f"found {self._gpu.get_gpu_count()} AMD GPUs")
    #   return
    self._gpu = NULLGPUStats()
    logging.warning("no GPU found, using NULLGPUStats")

  @property
  def gpu(self) -> GPUStats:
    if isinstance(self._gpu, NULLGPUStats) or self._gpu.get_gpu_count() == 0:
      if time.monotonic() - self.last_gpu_init > 10:
        self._init_gpu()
    return self._gpu

  def get_cpu_utilizations(self) -> list[float]:
    return psutil.cpu_percent(percpu=True)

  def get_cpu_power_draw(self) -> int:
    with open("/sys/class/powercap/intel-rapl/intel-rapl:0/energy_uj", "r") as f:
      current_energy = int(f.read().strip())
    current_time = time.monotonic()
    power_draw = (current_energy - self.last_energy) / (current_time - self.last_energy_time) / 1e6
    if power_draw < 0:
      # energy counter rolled over
      power_draw = current_energy / (current_time - self.last_energy_time) / 1e6
    self.last_energy, self.last_energy_time = current_energy, current_time
    return int(power_draw)

  def get_disk_io_per_second(self) -> tuple[int, int]:
    counter = psutil.disk_io_counters()
    if counter is None:
      return 0, 0
    current_time = time.monotonic()
    disk_read = (counter.read_bytes - self.last_disk_read) / (current_time - self.last_disk_time)
    disk_write = (counter.write_bytes - self.last_disk_write) / (current_time - self.last_disk_time)
    self.last_disk_read, self.last_disk_write, self.last_disk_time = counter.read_bytes, counter.write_bytes, current_time
    return int(disk_read / 1e6), int(disk_write / 1e6)
