---
name: ece-host-os-container-runtime
description: Diagnoses ECE host OS and container runtime issues including Docker daemon problems, Podman migration and runtime issues, SELinux-related failures, OverlayFS and kernel incompatibility, unsupported VMotion behavior, file system and storage driver issues, host prerequisite failures, and service user and permissions issues.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ECE — Host OS / Container Runtime Sub-Agent

Scope: Docker daemon issues, Podman migration/runtime, SELinux failures, OverlayFS/kernel incompatibility, unsupported VMotion, file system/storage driver issues, host prerequisites not met, service user/permissions issues.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"ECE Docker daemon failure"`, `"ECE Podman migration issue"`, `"ECE SELinux failure"`, `"ECE OverlayFS kernel"`, `"ECE host prerequisites"`, `"ECE VMotion unsupported"`.

## Diagnostic Steps

### 1. Docker / Podman Runtime Status
```bash
# Docker
systemctl status docker
docker info 2>&1 | grep -E "Server Version|Storage Driver|Logging Driver|Operating System|Kernel Version|ERROR"

# Podman (ECE 3.x+ supports Podman)
systemctl status podman 2>/dev/null
podman info 2>/dev/null | grep -E "version|storageDriver|rootlessNetworkCmd"
```

### 2. ECE Storage Driver — OverlayFS
ECE requires the `overlay2` storage driver. Other drivers (devicemapper, aufs) are not supported:
```bash
docker info | grep "Storage Driver"
```
If not `overlay2`:
```bash
# Check kernel support for overlay2
modprobe overlay && echo "overlay module OK" || echo "overlay module FAIL"
grep "overlay" /proc/filesystems
```
Kernel requirements: Linux 4.18+ recommended for OverlayFS with ECE.

### 3. Docker Daemon Errors
```bash
# Check Docker daemon logs
journalctl -u docker --since "1 hour ago" --no-pager | grep -E "ERROR|WARN|failed|panic" | tail -20

# Docker daemon config
cat /etc/docker/daemon.json 2>/dev/null | python3 -m json.tool
```
Common Docker daemon issues:
- `failed to start daemon: Error initializing network controller` → networking issue
- `dial unix /var/run/docker.sock: connect: no such file or directory` → Docker not running
- `devicemapper: Error mounting` → storage driver issue

### 4. Podman Migration Issues (ECE 3.x)
ECE 3.x introduced support for Podman as the container runtime:
```bash
# Check which runtime ECE is using
cat /mnt/data/elastic/bootstrap/container-engine 2>/dev/null

# If migrating from Docker to Podman, verify migration completed
podman info --format json | jq '.host.cgroupManager'  # should be "systemd"

# Podman rootless mode issues
ls -la /run/user/$(id -u elastic)/podman/ 2>/dev/null
```
Podman migration requires the ECE installer to be run with `--podman` flag.

### 5. SELinux Issues
```bash
# Check SELinux mode
getenforce 2>/dev/null || sestatus 2>/dev/null | grep "Current mode"

# Check for SELinux denials related to ECE/Docker
ausearch -m AVC -ts recent 2>/dev/null | grep -E "docker|elastic|container" | tail -10
# Or
grep "avc:.*denied" /var/log/audit/audit.log | grep -E "docker|elastic" | tail -10
```
SELinux in `Enforcing` mode can block Docker containers from accessing files in `/mnt/data/elastic/`.

Fix: apply ECE SELinux policy or set specific file contexts:
```bash
# Apply Docker/container SELinux policy
semanage fcontext -a -t container_file_t "/mnt/data/elastic(/.*)?"
restorecon -Rv /mnt/data/elastic
```
Or install with `--selinux` flag during ECE installation.

### 6. VMotion / Live Migration (Unsupported)
ECE is not supported on VMware infrastructure with VMotion enabled:
- VMotion migrates VMs between hypervisor hosts
- ZooKeeper uses host-based clocks and session timeouts
- VMotion pause can cause ZK session expiry and platform instability

If VMotion is suspected:
```bash
# Check for ZK session expiry events correlating with VMotion times
docker logs frc-directors-director 2>&1 | grep -E "SessionExpired|VMotion" | head -10
# Check ZK transaction ID discontinuity
docker exec frc-zookeeper-0 bash -c "echo stat | nc localhost 2181" | grep "Zxid"
```
Disable VMotion for ECE hosts or use VM-host affinity rules to prevent migration.

### 7. Host Prerequisite Check
```bash
# Kernel version (4.18+ recommended)
uname -r

# File descriptor limits
ulimit -n
cat /proc/sys/fs/file-max

# vm.max_map_count (must be >= 262144 for Elasticsearch)
sysctl vm.max_map_count

# Swap (should be disabled for ES, but ECE platform needs it for OOM management)
free -h | grep Swap

# Available disk space for ECE data directory
df -h /mnt/data
```

### 8. Service User and Permissions
ECE runs as the `elastic` user:
```bash
# Check elastic user
id elastic
groups elastic

# Check Docker group membership (must be in docker group)
groups elastic | grep docker

# Check ECE data directory permissions
ls -la /mnt/data/elastic/
stat /mnt/data/elastic/ | grep -E "Uid|Gid|Access"
```
If `elastic` user is not in the `docker` group or doesn't own `/mnt/data/elastic`: ECE will fail to start containers.

### 9. Container Storage Issue
```bash
# Check Docker's storage usage
docker system df

# Find large or orphaned volumes
docker volume ls --filter "dangling=true"

# Check if /mnt/data disk is full
df -h /mnt/data
du -sh /mnt/data/elastic/*/ 2>/dev/null | sort -rh | head -10
```
Disk full = containers fail to start, ECE becomes unstable.

### 10. KCS + Docs Lookup
Execute retrieval protocol with the specific OS issue (Docker error, SELinux, kernel version), the ECE version, and the Linux distribution.

## Token Budget
- `docker info` and `systemctl status docker` give instant runtime baseline.
- `sysctl vm.max_map_count` and `ulimit` for prerequisite checks.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
