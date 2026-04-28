package lab.geode.client;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.Arrays;
import java.util.concurrent.CountDownLatch;

import org.apache.geode.cache.EntryEvent;
import org.apache.geode.cache.InterestResultPolicy;
import org.apache.geode.cache.Region;
import org.apache.geode.cache.client.ClientCache;
import org.apache.geode.cache.client.ClientCacheFactory;
import org.apache.geode.cache.client.ClientRegionFactory;
import org.apache.geode.cache.client.ClientRegionShortcut;
import org.apache.geode.cache.util.CacheListenerAdapter;

import io.opentelemetry.api.GlobalOpenTelemetry;
import io.opentelemetry.api.trace.Span;
import io.opentelemetry.api.trace.Tracer;
import io.opentelemetry.context.Scope;

public final class ActivityClientApp {
  private static final String DEFAULT_LOCATOR_HOST = "192.168.0.150";
  private static final int DEFAULT_LOCATOR_PORT = 10334;
  private static final String DEFAULT_REGION_NAME = "Activity";
  private static final Tracer TRACER = GlobalOpenTelemetry.getTracer("lab.geode.client");

  private ActivityClientApp() {
  }

  public static void main(String[] args) throws Exception {
    Config config = Config.parse(args);
    ClientCache cache = createCache(config);

    try {
      Region<String, String> region = createRegion(cache, config);
      run(region, config);
    } finally {
      cache.close();
    }
  }

  private static ClientCache createCache(Config config) {
    Span span = TRACER.spanBuilder("geode.connect")
        .setAttribute("geode.locator.host", config.locatorHost)
        .setAttribute("geode.locator.port", (long) config.locatorPort)
        .startSpan();
    try (Scope scope = span.makeCurrent()) {
      System.out.printf(
          "Connecting to locator %s:%d and region %s%n",
          config.locatorHost,
          Integer.valueOf(config.locatorPort),
          config.regionName);
      return new ClientCacheFactory()
          .addPoolLocator(config.locatorHost, config.locatorPort)
          .setPoolSubscriptionEnabled(true)
          .set("log-level", "warn")
          .create();
    } finally {
      span.end();
    }
  }

  private static Region<String, String> createRegion(ClientCache cache, Config config) {
    ClientRegionFactory<String, String> regionFactory =
        cache.<String, String>createClientRegionFactory(ClientRegionShortcut.CACHING_PROXY);
    regionFactory.addCacheListener(new ActivityListener());
    return regionFactory.create(config.regionName);
  }

  private static void run(Region<String, String> region, Config config) throws Exception {
    if ("publish".equals(config.command)) {
      publish(region, config.publishKey, config.publishValue);
      return;
    }

    subscribe(region);

    if ("interactive".equals(config.command)) {
      interactivePublishLoop(region);
      return;
    }

    System.out.println("Subscriber is running. Press Ctrl+C to exit.");
    new CountDownLatch(1).await();
  }

  private static void subscribe(Region<String, String> region) {
    Span span = TRACER.spanBuilder("geode.subscribe")
        .setAttribute("geode.region", region.getName())
        .startSpan();
    try (Scope scope = span.makeCurrent()) {
      region.registerInterestForAllKeys(InterestResultPolicy.NONE);
      System.out.printf("Subscribed to all keys in region %s%n", region.getName());
    } finally {
      span.end();
    }
  }

  private static void publish(Region<String, String> region, String key, String value) {
    Span span = TRACER.spanBuilder("geode.put")
        .setAttribute("geode.region", region.getName())
        .setAttribute("geode.key", key)
        .startSpan();
    try (Scope scope = span.makeCurrent()) {
      region.put(key, value);
      System.out.printf("Published key=%s value=%s%n", key, value);
    } finally {
      span.end();
    }
  }

  private static void interactivePublishLoop(Region<String, String> region) throws IOException {
    BufferedReader reader = new BufferedReader(new InputStreamReader(System.in));
    System.out.println("Interactive mode. Enter key=value, or type exit.");

    while (true) {
      System.out.print("> ");
      String line = reader.readLine();
      if (line == null) {
        return;
      }

      String trimmed = line.trim();
      if (trimmed.isEmpty()) {
        continue;
      }
      if ("exit".equalsIgnoreCase(trimmed)) {
        return;
      }

      int separatorIndex = trimmed.indexOf('=');
      if (separatorIndex <= 0 || separatorIndex == trimmed.length() - 1) {
        System.out.println("Expected key=value");
        continue;
      }

      String key = trimmed.substring(0, separatorIndex).trim();
      String value = trimmed.substring(separatorIndex + 1).trim();
      publish(region, key, value);
    }
  }

  private static void printUsage() {
    System.out.println("Usage:");
    System.out.println("  ActivityClientApp [--locator-host HOST] [--locator-port PORT] [--region NAME] subscribe");
    System.out.println("  ActivityClientApp [--locator-host HOST] [--locator-port PORT] [--region NAME] interactive");
    System.out.println("  ActivityClientApp [--locator-host HOST] [--locator-port PORT] [--region NAME] publish <key> <value>");
    System.out.println();
    System.out.println("Defaults:");
    System.out.printf("  locator host: %s%n", DEFAULT_LOCATOR_HOST);
    System.out.printf("  locator port: %d%n", Integer.valueOf(DEFAULT_LOCATOR_PORT));
    System.out.printf("  region: %s%n", DEFAULT_REGION_NAME);
  }

  private static final class ActivityListener extends CacheListenerAdapter<String, String> {
    @Override
    public void afterCreate(EntryEvent<String, String> event) {
      printEvent("CREATE", event);
    }

    @Override
    public void afterUpdate(EntryEvent<String, String> event) {
      printEvent("UPDATE", event);
    }

    @Override
    public void afterDestroy(EntryEvent<String, String> event) {
      printEvent("DESTROY", event);
    }

    private void printEvent(String operation, EntryEvent<String, String> event) {
      System.out.printf(
          "[%s] key=%s oldValue=%s newValue=%s%n",
          operation,
          event.getKey(),
          event.getOldValue(),
          event.getNewValue());
    }
  }

  private static final class Config {
    private final String locatorHost;
    private final int locatorPort;
    private final String regionName;
    private final String command;
    private final String publishKey;
    private final String publishValue;

    private Config(
        String locatorHost,
        int locatorPort,
        String regionName,
        String command,
        String publishKey,
        String publishValue) {
      this.locatorHost = locatorHost;
      this.locatorPort = locatorPort;
      this.regionName = regionName;
      this.command = command;
      this.publishKey = publishKey;
      this.publishValue = publishValue;
    }

    private static Config parse(String[] args) {
      String locatorHost = DEFAULT_LOCATOR_HOST;
      int locatorPort = DEFAULT_LOCATOR_PORT;
      String regionName = DEFAULT_REGION_NAME;
      int index = 0;

      while (index < args.length && args[index].startsWith("--")) {
        String option = args[index];
        if ("--locator-host".equals(option)) {
          locatorHost = requireValue(args, index, option);
          index += 2;
          continue;
        }
        if ("--locator-port".equals(option)) {
          locatorPort = Integer.parseInt(requireValue(args, index, option));
          index += 2;
          continue;
        }
        if ("--region".equals(option)) {
          regionName = requireValue(args, index, option);
          index += 2;
          continue;
        }

        throw usageError("Unknown option: " + option);
      }

      if (index >= args.length) {
        throw usageError("Missing command");
      }

      String command = args[index];
      if ("subscribe".equals(command) || "interactive".equals(command)) {
        if (index != args.length - 1) {
          throw usageError("Unexpected arguments: " + Arrays.toString(Arrays.copyOfRange(args, index + 1, args.length)));
        }
        return new Config(locatorHost, locatorPort, regionName, command, null, null);
      }

      if ("publish".equals(command)) {
        if (index + 2 >= args.length) {
          throw usageError("publish requires <key> <value>");
        }
        String key = args[index + 1];
        String value = join(args, index + 2);
        return new Config(locatorHost, locatorPort, regionName, command, key, value);
      }

      throw usageError("Unknown command: " + command);
    }

    private static String requireValue(String[] args, int index, String option) {
      if (index + 1 >= args.length) {
        throw usageError("Missing value for " + option);
      }
      return args[index + 1];
    }

    private static String join(String[] args, int startIndex) {
      StringBuilder builder = new StringBuilder();
      for (int i = startIndex; i < args.length; i++) {
        if (i > startIndex) {
          builder.append(' ');
        }
        builder.append(args[i]);
      }
      return builder.toString();
    }

    private static IllegalArgumentException usageError(String message) {
      printUsage();
      return new IllegalArgumentException(message);
    }
  }
}
