import sys, time

TMPDIR = sys.argv[1]
PARALLEL_RSYNC = int(sys.argv[2])

with open(f"{TMPDIR}/files.all", "r") as f:
  rawfiles = f.readlines()

# format is "fsize fname"
files = []
for f in rawfiles:
  try: files.append((int(f.split(" ")[0]), " ".join(f.split(" ")[1:]).strip()))
  except: pass

# put file in the chunk with the smallest size
chunks = [[0, []] for _ in range(PARALLEL_RSYNC)]
st = time.monotonic()
for i, f in enumerate(files):
  min_chunk = min(chunks, key=lambda x: x[0])
  min_chunk[1].append(f[1])
  min_chunk[0] += f[0]

  if i % 25000 == 0: print(f"\033[0;32mINFO: {i} of {len(files)} ({int(time.monotonic() - st)}s)\033[0m")

# write chunks
for i, c in enumerate(chunks):
  with open(f"{TMPDIR}/chunk.{i}", "w") as f:
    f.write("\n".join(c[1]) + "\n")

# write the total size of all files
with open(f"{TMPDIR}/total.size", "w") as f:
  f.write(str(sum([f[0] for f in files])))
