# Hulk Locator Enablement Runbook

This runbook prepares `Hulk` to host `locator2` for Cluster A by folding locator startup and shutdown into the existing Hulk `start_geode.sh` and `stop_geode.sh` flow.

Current repo baseline:

- `locator1` on `Antman` is the only validated locator for Cluster A.
- `scripts/Hulk/start_geode.sh` now starts `locator2` first and then `server2`.
- `scripts/Hulk/stop_geode.sh` now stops `server2` first and then `locator2`.

## Target Topology

After cutover, Cluster A should look like this:

```text
                +-------------------------------+
                | locator1                      |
                | Host: Antman                  |
                | IP: 192.168.0.150             |
                | Locator: 10334/tcp            |
                +---------------+---------------+
                                |
              locators=Antman[10334],Hulk[10334]
                                |
                +---------------+---------------+
                |                               |
    +-----------v-----------+       +-----------v-----------+
    | server1               |       | locator2              |
    | Host: Antman          |       | Host: Hulk            |
    | Cache Server: 40404   |       | Locator: 10334/tcp    |
    +-----------------------+       +---------------+-------+
                                                    |
                                        +-----------v-----------+
                                        | server2               |
                                        | Host: Hulk            |
                                        | Cache Server: 40405   |
                                        +-----------------------+
```

## Prerequisites

Apply these on `Hulk` before starting `locator2`:

1. Java 11 and Geode 1.15.2 must be installed at the same paths already assumed by `scripts/Hulk/start_geode.sh`.
2. `Antman` and `Hulk` must resolve by hostname on both hosts.
3. `Hulk` must have the same Cluster A locator properties file that `locator1` on `Antman` already uses.
4. Peer traffic between `192.168.0.150` and `192.168.0.151` must allow both `TCP` and `UDP`.

Expected host paths on `Hulk`:

```bash
/home/alex/apache-geode-1.15.2
/home/alex/geode_cluster
/home/alex/geode_cluster/gemfire-wan-a.properties
```

Expected member directories after rollout:

```bash
/home/alex/geode_cluster/locator2
/home/alex/geode_cluster/server2
```

## Repo Script Behavior

### `scripts/Hulk/start_geode.sh`

- Starts `locator2` on `Hulk`
- Waits briefly for the local locator to come up
- Connects to the local locator and starts `server2`
- Defaults to `LOCATORS=Antman[10334],Hulk[10334]`
- Requires `LOCATOR_PROPERTIES=/home/alex/geode_cluster/gemfire-wan-a.properties` unless overridden

Example cutover invocation:

```bash
/home/alex/geode_cluster/start-hulk-geode.sh
```

## Rollout Sequence

Follow this order to reduce cluster risk:

1. Confirm `locator1` and `server1` are healthy on `Antman`.
2. Copy the updated Hulk `start_geode.sh` and `stop_geode.sh` to `Hulk`, make them executable, and confirm the properties file path is correct.
3. Start the combined Hulk flow so `locator2` comes up before `server2`.
4. Validate that `locator2` joined Cluster A and cluster configuration is available through it.
5. Confirm `server2` joined with `LOCATORS="Antman[10334],Hulk[10334]"`.
6. Normalize `locator1` and `server1` on `Antman` so their startup commands also reference `Antman[10334],Hulk[10334]`.
7. Re-run member and region validation before any WAN testing.

## Host Commands

These are the intended host-side commands once you are ready to execute the rollout.

Start `locator2` and `server2` together on `Hulk`:

```bash
chmod +x /home/alex/geode_cluster/start-hulk-geode.sh
/home/alex/geode_cluster/start-hulk-geode.sh
```

Equivalent explicit invocation if you do not rename the script:

```bash
chmod +x ./scripts/Hulk/start_geode.sh
./scripts/Hulk/start_geode.sh
```

Recommended Antman normalization:

```bash
gfsh -e "start locator \
  --name=locator1 \
  --dir=/home/alex/geode_cluster/locator1 \
  --port=10334 \
  --hostname-for-clients=192.168.0.150 \
  --locators=Antman[10334],Hulk[10334] \
  --properties-file=/home/alex/geode_cluster/gemfire-wan-a.properties \
  --J=-Dgemfire.jmx-manager-port=1099 \
  --J=-Dgemfire.http-service-port=7070"

gfsh -e "connect --locator=Antman[10334]" \
  -e "start server \
    --name=server1 \
    --dir=/home/alex/geode_cluster/server1 \
    --server-port=40404 \
    --locators=Antman[10334],Hulk[10334] \
    --hostname-for-clients=192.168.0.150 \
    --http-service-port=7071 \
    --groups=wan-sender \
    --J=-Dgemfire.start-dev-rest-api=true \
    --J=-javaagent:/opt/jmx-exporter/jmx_prometheus_javaagent.jar=9404:/opt/jmx-exporter/geode-jmx.yml"
```

Reason for the manual commands:

- the current repo-side Antman scripts were already modified in your worktree
- those scripts do not yet expose a separate locator list variable for the locator startup path
- this runbook keeps the Hulk enablement isolated instead of editing your in-progress Antman files

## Validation

Validate through `gfsh` after each restart:

```bash
connect --locator=Antman[10334]
list members
describe member --name=locator1
describe member --name=locator2
describe member --name=server1
describe member --name=server2
list regions
```

Host-level checks:

```bash
ss -ltnp | grep 10334
ss -ltnp | grep 1099
ss -ltnp | grep 7070
tail -n 80 /home/alex/geode_cluster/locator2/locator2.log
tail -n 80 /home/alex/geode_cluster/server2/server2.log
```

Expected steady state:

- `locator1`, `locator2`, `server1`, and `server2` are listed
- `locator2` appears on host `Hulk`
- `server2` rejoins cleanly with the dual-locator list
- Region definitions remain intact
- WAN sender and receiver config remain present

## Rollback

If `locator2` destabilizes the cluster:

1. Stop `server2` on `Hulk`.
2. Stop `locator2` on `Hulk`.
3. If needed, temporarily revert the script or run an older single-locator copy of `start_geode.sh` with `LOCATORS=Antman[10334]`.
4. Keep `Antman` on the original single-locator configuration.
5. Review `locator2.log` before retrying.

Rollback commands on `Hulk`:

```bash
./scripts/Hulk/stop_geode.sh
```

## Notes

- This repo change does not execute anything on the lab hosts.
- Actual host inspection or validation should use the Query Service API by default unless you explicitly switch to step-by-step mode or override that rule.
