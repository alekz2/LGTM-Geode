# Activity Client

Minimal Java client for the Apache Geode `Activity` region.

The defaults in this project align with the Geode lab documents in this repository:

- locator host: `192.168.0.150`
- locator port: `10334`
- region: `Activity`
- Geode version: `1.15.2`

## What it does

- `subscribe`: connects to Geode, registers interest for all keys in `Activity`, and prints create/update/destroy events
- `publish`: writes a single key/value pair into `Activity`
- `interactive`: subscribes for events and lets you publish from stdin in the same process

## Project layout

- `src/main/java/lab/geode/client/ActivityClientApp.java`: single entry point
- `out`: local compile output created by `javac`

## Prerequisites

- Java 11 JDK with `javac` and `java`
- `GEODE_HOME` pointing to a local Apache Geode installation so the client can use `GEODE_HOME\lib\*`

Example in `cmd.exe`:

```cmd
set JAVA_HOME=D:\Alex\Tools\Java\temurin-11
set PATH=%JAVA_HOME%\bin;%PATH%
set GEODE_HOME=D:\path\to\apache-geode-1.15.2
```

## Install Apache Geode On Ironman

This client does not need a local Geode server on Ironman. It only needs the Geode product libraries so `javac` and `java` can resolve the client classes.

1. Download Apache Geode `1.15.2` from the official Apache release directory.
2. Save `apache-geode-1.15.2.tgz` under `D:\Alex\Work\Installs`.
3. Extract it:

```cmd
cd D:\Alex\Work\Installs
tar -xzf apache-geode-1.15.2.tgz
```

4. Set `GEODE_HOME` for the current shell:

```cmd
set GEODE_HOME=D:\Alex\Work\Installs\apache-geode-1.15.2
```

5. Verify the install:

```cmd
"%GEODE_HOME%\bin\gfsh.bat" version
```

## Compile

```cmd
cd D:\Alex\Work\Installs\LGTM-Geode\client
if not exist out mkdir out
javac -cp "%GEODE_HOME%\lib\*" -d out src\main\java\lab\geode\client\ActivityClientApp.java
```

## Run

Subscriber:

```cmd
java -cp "out;%GEODE_HOME%\lib\*" lab.geode.client.ActivityClientApp subscribe
```

Publisher:

```cmd
java -cp "out;%GEODE_HOME%\lib\*" lab.geode.client.ActivityClientApp publish order-1001 created
```

Interactive publisher/subscriber:

```cmd
java -cp "out;%GEODE_HOME%\lib\*" lab.geode.client.ActivityClientApp interactive
```

Interactive mode accepts lines in `key=value` format. Type `exit` to stop.

## Override defaults

You can point to a different locator or region before the command:

```cmd
java -cp "out;%GEODE_HOME%\lib\*" lab.geode.client.ActivityClientApp --locator-host Antman --locator-port 10334 --region Activity subscribe
```

## Simple validation flow

1. Start one terminal with `subscribe`.
2. Start a second terminal with `publish demo-1 hello`.
3. Confirm the subscriber prints the event for key `demo-1`.

## Notes

- The client uses a `CACHING_PROXY` region so subscription events are visible locally.
- `registerInterestForAllKeys(InterestResultPolicy.NONE)` subscribes to future changes without loading the whole region up front.
- If you later move from `String` payloads to Java objects, revisit serialization and class compatibility as needed.
- If `GEODE_HOME` is not set or points to the wrong install, both `javac` and `java` will fail to resolve Geode classes.

## Optional: Java 17

If you choose to run this client with Java 17 instead of Java 11, Geode 1.15.2 typically requires extra JVM module access flags. In that case, create a `java17-geode.args` file and pass it to both `javac` and `java`.
