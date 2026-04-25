package lab.geode.client;

import java.lang.management.GarbageCollectorMXBean;
import java.lang.management.ManagementFactory;
import java.lang.management.MemoryMXBean;
import java.lang.management.MemoryUsage;
import java.lang.management.OperatingSystemMXBean;
import java.lang.management.ThreadMXBean;
import java.util.ArrayList;
import java.util.ArrayDeque;
import java.util.Arrays;
import java.util.List;
import java.util.Random;
import java.util.concurrent.atomic.AtomicBoolean;

public final class StressTestApp {

  private StressTestApp() {
  }

  public static void main(String[] args) throws InterruptedException {
    Config config = Config.parse(args);
    run(config);
  }

  private static void run(Config config) throws InterruptedException {
    AtomicBoolean running = new AtomicBoolean(true);

    Runtime.getRuntime().addShutdownHook(new Thread(() -> {
      System.out.println("[SHUTDOWN] Stopping stressors...");
      running.set(false);
    }, "shutdown-hook"));

    int resolvedThreadCount = config.threadCount > 0
        ? config.threadCount
        : config.intensity.defaultThreadCount();

    System.out.printf(
        "[START] mode=%s duration=%ds intensity=%s threads=%d interval=%ds%n",
        config.mode.name().toLowerCase(),
        Integer.valueOf(config.durationSeconds),
        config.intensity.name().toLowerCase(),
        Integer.valueOf(resolvedThreadCount),
        Integer.valueOf(config.intervalSeconds));

    Thread statsThread = new Thread(
        new StatsReporter(config.intervalSeconds), "stats-reporter");
    statsThread.setDaemon(true);
    statsThread.start();

    List<Runnable> stressors = buildStressors(config, running, resolvedThreadCount);
    List<Thread> stressorThreads = new ArrayList<>();
    for (Runnable stressor : stressors) {
      Thread t = new Thread(stressor, stressor.getClass().getSimpleName());
      t.setDaemon(false);
      stressorThreads.add(t);
      t.start();
    }

    Thread.sleep(config.durationSeconds * 1000L);
    running.set(false);

    for (Thread t : stressorThreads) {
      t.join(5000L);
    }

    statsThread.interrupt();
    System.out.println("[DONE]  Stress test complete.");
  }

  private static List<Runnable> buildStressors(
      Config config, AtomicBoolean running, int threadCount) {
    List<Runnable> list = new ArrayList<>();
    Mode m = config.mode;
    if (m == Mode.HEAP    || m == Mode.ALL) list.add(new HeapStressor(config.intensity, running));
    if (m == Mode.THREADS || m == Mode.ALL) list.add(new ThreadStressor(threadCount, running));
    if (m == Mode.CPU     || m == Mode.ALL) list.add(new CpuStressor(threadCount, running));
    if (m == Mode.BASELINE)                 list.add(new BaselineMode(running));
    return list;
  }

  private static void sleepMillis(long millis) {
    try {
      Thread.sleep(millis);
    } catch (InterruptedException e) {
      Thread.currentThread().interrupt();
    }
  }

  private static void printUsage() {
    System.out.println("Usage:");
    System.out.println("  StressTestApp --mode MODE [options]");
    System.out.println();
    System.out.println("Required:");
    System.out.println("  --mode MODE       heap | threads | cpu | baseline | all");
    System.out.println();
    System.out.println("Options:");
    System.out.println("  --duration N      Run for N seconds (default: 60)");
    System.out.println("  --intensity LEVEL low | medium | high (default: medium)");
    System.out.println("  --threads N       Override thread count for threads/cpu modes");
    System.out.println("  --interval N      Stats print interval in seconds (default: 5)");
    System.out.println();
    System.out.println("Intensity defaults:");
    System.out.println("  low    threads=10  heap-target=32MB");
    System.out.println("  medium threads=50  heap-target=128MB");
    System.out.println("  high   threads=200 heap-target=512MB");
    System.out.println();
    System.out.println("Notes:");
    System.out.println("  --threads is ignored for baseline mode.");
    System.out.println("  For high intensity heap or all mode, start with -Xmx768m or larger.");
  }

  // ── Enums ──────────────────────────────────────────────────────────────────

  private enum Mode {
    HEAP, THREADS, CPU, BASELINE, ALL;

    static Mode parse(String s) {
      try {
        return Mode.valueOf(s.toUpperCase());
      } catch (IllegalArgumentException e) {
        throw usageError("Unknown mode: " + s + " (expected heap|threads|cpu|baseline|all)");
      }
    }
  }

  private enum Intensity {
    LOW, MEDIUM, HIGH;

    static Intensity parse(String s) {
      try {
        return Intensity.valueOf(s.toUpperCase());
      } catch (IllegalArgumentException e) {
        throw usageError("Unknown intensity: " + s + " (expected low|medium|high)");
      }
    }

    int defaultThreadCount() {
      switch (this) {
        case LOW:    return 10;
        case MEDIUM: return 50;
        case HIGH:   return 200;
        default: throw new AssertionError(this);
      }
    }

    long heapTargetBytes() {
      switch (this) {
        case LOW:    return 32L  * 1024 * 1024;
        case MEDIUM: return 128L * 1024 * 1024;
        case HIGH:   return 512L * 1024 * 1024;
        default: throw new AssertionError(this);
      }
    }

    int allocationChunkBytes() {
      switch (this) {
        case LOW:    return 1  * 1024 * 1024;
        case MEDIUM: return 4  * 1024 * 1024;
        case HIGH:   return 16 * 1024 * 1024;
        default: throw new AssertionError(this);
      }
    }
  }

  // ── Config ─────────────────────────────────────────────────────────────────

  private static final class Config {
    private final Mode      mode;
    private final int       durationSeconds;
    private final Intensity intensity;
    private final int       threadCount;
    private final int       intervalSeconds;

    private Config(Mode mode, int durationSeconds, Intensity intensity,
                   int threadCount, int intervalSeconds) {
      this.mode            = mode;
      this.durationSeconds = durationSeconds;
      this.intensity       = intensity;
      this.threadCount     = threadCount;
      this.intervalSeconds = intervalSeconds;
    }

    private static Config parse(String[] args) {
      Mode      mode            = null;
      int       durationSeconds = 60;
      Intensity intensity       = Intensity.MEDIUM;
      int       threadCount     = -1;
      int       intervalSeconds = 5;
      int index = 0;

      while (index < args.length) {
        String option = args[index];
        if ("--mode".equals(option)) {
          mode = Mode.parse(requireValue(args, index, option));
          index += 2;
        } else if ("--duration".equals(option)) {
          durationSeconds = Integer.parseInt(requireValue(args, index, option));
          index += 2;
        } else if ("--intensity".equals(option)) {
          intensity = Intensity.parse(requireValue(args, index, option));
          index += 2;
        } else if ("--threads".equals(option)) {
          threadCount = Integer.parseInt(requireValue(args, index, option));
          index += 2;
        } else if ("--interval".equals(option)) {
          intervalSeconds = Integer.parseInt(requireValue(args, index, option));
          index += 2;
        } else {
          throw usageError("Unknown option: " + option);
        }
      }

      if (mode == null) {
        throw usageError("--mode is required");
      }

      return new Config(mode, durationSeconds, intensity, threadCount, intervalSeconds);
    }

    private static String requireValue(String[] args, int index, String option) {
      if (index + 1 >= args.length) {
        throw usageError("Missing value for " + option);
      }
      return args[index + 1];
    }
  }

  private static IllegalArgumentException usageError(String message) {
    printUsage();
    return new IllegalArgumentException(message);
  }

  // ── StatsReporter ──────────────────────────────────────────────────────────

  private static final class StatsReporter implements Runnable {
    private final int intervalSeconds;
    private final MemoryMXBean memoryBean;
    private final ThreadMXBean threadBean;
    private final List<GarbageCollectorMXBean> gcBeans;
    private final com.sun.management.OperatingSystemMXBean sunOsBean;

    StatsReporter(int intervalSeconds) {
      this.intervalSeconds = intervalSeconds;
      this.memoryBean = ManagementFactory.getMemoryMXBean();
      this.threadBean = ManagementFactory.getThreadMXBean();
      this.gcBeans    = ManagementFactory.getGarbageCollectorMXBeans();

      OperatingSystemMXBean raw = ManagementFactory.getOperatingSystemMXBean();
      com.sun.management.OperatingSystemMXBean sun = null;
      if (raw instanceof com.sun.management.OperatingSystemMXBean) {
        sun = (com.sun.management.OperatingSystemMXBean) raw;
      }
      this.sunOsBean = sun;
    }

    @Override
    public void run() {
      while (!Thread.currentThread().isInterrupted()) {
        printStats();
        try {
          Thread.sleep(intervalSeconds * 1000L);
        } catch (InterruptedException e) {
          Thread.currentThread().interrupt();
          break;
        }
      }
    }

    private void printStats() {
      MemoryUsage heap    = memoryBean.getHeapMemoryUsage();
      MemoryUsage nonHeap = memoryBean.getNonHeapMemoryUsage();

      long heapUsedMB  = heap.getUsed()    / (1024 * 1024);
      long heapMaxMB   = heap.getMax()     / (1024 * 1024);
      long nonHeapUsed = nonHeap.getUsed() / (1024 * 1024);

      int  liveThreads   = threadBean.getThreadCount();
      int  peakThreads   = threadBean.getPeakThreadCount();
      int  daemonThreads = threadBean.getDaemonThreadCount();

      long gcCount = 0;
      long gcTimeMs = 0;
      for (GarbageCollectorMXBean gc : gcBeans) {
        long count = gc.getCollectionCount();
        long time  = gc.getCollectionTime();
        gcCount  += count  < 0 ? 0 : count;
        gcTimeMs += time   < 0 ? 0 : time;
      }

      String cpuStr;
      if (sunOsBean != null) {
        double cpuLoad = sunOsBean.getProcessCpuLoad();
        // getProcessCpuLoad() returns -1.0 when the value is not yet available
        cpuStr = cpuLoad < 0.0
            ? "N/A"
            : String.format("%.1f%%", Double.valueOf(cpuLoad * 100.0));
      } else {
        cpuStr = "N/A";
      }

      System.out.printf(
          "[STATS] heap=%d/%dMB nonheap=%dMB threads=%d/%d/%dd gc=%d/%dms cpu=%s%n",
          Long.valueOf(heapUsedMB),
          Long.valueOf(heapMaxMB),
          Long.valueOf(nonHeapUsed),
          Integer.valueOf(liveThreads),
          Integer.valueOf(peakThreads),
          Integer.valueOf(daemonThreads),
          Long.valueOf(gcCount),
          Long.valueOf(gcTimeMs),
          cpuStr);
    }
  }

  // ── HeapStressor ───────────────────────────────────────────────────────────

  private static final class HeapStressor implements Runnable {
    private final Intensity   intensity;
    private final AtomicBoolean running;
    private final ArrayDeque<byte[]> liveObjects = new ArrayDeque<>();
    private long currentLiveBytes = 0;

    HeapStressor(Intensity intensity, AtomicBoolean running) {
      this.intensity = intensity;
      this.running   = running;
    }

    @Override
    public void run() {
      long targetBytes = intensity.heapTargetBytes();
      int  chunkBytes  = intensity.allocationChunkBytes();

      System.out.printf(
          "[HEAP]  Starting. Target=%dMB chunk=%dMB%n",
          Long.valueOf(targetBytes  / (1024 * 1024)),
          Integer.valueOf(chunkBytes / (1024 * 1024)));

      while (running.get()) {
        // Phase 1: fill up to target
        while (running.get() && currentLiveBytes < targetBytes) {
          byte[] chunk = new byte[chunkBytes];
          Arrays.fill(chunk, (byte) 0xAB);  // prevent JIT dead-code elimination
          liveObjects.addLast(chunk);
          currentLiveBytes += chunkBytes;
        }
        sleepMillis(200);

        // Phase 2: release half to trigger GC cycles
        long releaseTarget = currentLiveBytes / 2;
        while (!liveObjects.isEmpty() && currentLiveBytes > releaseTarget) {
          byte[] released = liveObjects.pollFirst();
          currentLiveBytes -= released.length;
        }
        sleepMillis(100);
      }

      liveObjects.clear();
      System.out.println("[HEAP]  Stopped.");
    }
  }

  // ── ThreadStressor ─────────────────────────────────────────────────────────

  private static final class ThreadStressor implements Runnable {
    private final int           threadCount;
    private final AtomicBoolean running;
    private final List<Thread>  workerThreads = new ArrayList<>();

    ThreadStressor(int threadCount, AtomicBoolean running) {
      this.threadCount = threadCount;
      this.running     = running;
    }

    @Override
    public void run() {
      System.out.printf("[THRD]  Starting %d worker threads.%n", Integer.valueOf(threadCount));

      for (int i = 0; i < threadCount; i++) {
        final int id = i;
        Thread t = new Thread(() -> {
          Random rng = new Random();
          int[] arr = new int[100];
          while (running.get()) {
            try {
              Thread.sleep(rng.nextInt(100) + 50);
            } catch (InterruptedException e) {
              Thread.currentThread().interrupt();
              break;
            }
            for (int j = 0; j < arr.length; j++) {
              arr[j] = rng.nextInt();
            }
            Arrays.sort(arr);
          }
        }, "stress-thread-" + id);
        t.setDaemon(true);
        workerThreads.add(t);
        t.start();
      }

      while (running.get()) {
        sleepMillis(500);
      }

      for (Thread t : workerThreads) {
        t.interrupt();
      }
      for (Thread t : workerThreads) {
        try {
          t.join(2000L);
        } catch (InterruptedException e) {
          Thread.currentThread().interrupt();
          break;
        }
      }
      System.out.println("[THRD]  Stopped.");
    }
  }

  // ── CpuStressor ────────────────────────────────────────────────────────────

  private static final class CpuStressor implements Runnable {
    private final int           threadCount;
    private final AtomicBoolean running;
    private final List<Thread>  workerThreads = new ArrayList<>();

    CpuStressor(int threadCount, AtomicBoolean running) {
      this.threadCount = threadCount;
      this.running     = running;
    }

    @Override
    public void run() {
      System.out.printf("[CPU]   Starting %d CPU threads.%n", Integer.valueOf(threadCount));

      for (int i = 0; i < threadCount; i++) {
        final int id = i;
        Thread t = new Thread(() -> {
          while (running.get()) {
            // Sieve of Eratosthenes — purely CPU-bound, bounded memory footprint
            boolean[] sieve = new boolean[100_000];
            Arrays.fill(sieve, true);
            for (int k = 2; k * (long) k < sieve.length; k++) {
              if (sieve[k]) {
                for (int m = k * k; m < sieve.length; m += k) {
                  sieve[m] = false;
                }
              }
            }
            // The volatile read of running.get() at the top of the loop prevents
            // the JIT from hoisting the sieve computation out of the loop.
          }
        }, "cpu-stress-" + id);
        t.setDaemon(true);
        workerThreads.add(t);
        t.start();
      }

      while (running.get()) {
        sleepMillis(500);
      }

      for (Thread t : workerThreads) {
        t.interrupt();
      }
      for (Thread t : workerThreads) {
        try {
          t.join(2000L);
        } catch (InterruptedException e) {
          Thread.currentThread().interrupt();
          break;
        }
      }
      System.out.println("[CPU]   Stopped.");
    }
  }

  // ── BaselineMode ───────────────────────────────────────────────────────────

  private static final class BaselineMode implements Runnable {
    private final AtomicBoolean running;

    BaselineMode(AtomicBoolean running) {
      this.running = running;
    }

    @Override
    public void run() {
      System.out.println("[BASE]  No load applied. JVM metrics observable at idle.");
      while (running.get()) {
        sleepMillis(1000);
      }
      System.out.println("[BASE]  Stopped.");
    }
  }
}
