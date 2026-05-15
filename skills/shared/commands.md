# Troubleshooting & Validation Commands

Use these commands to validate issues across the Elastic Stack, ECE platform, Kubernetes (ECK), and underlying infrastructure. This list is not exhaustive; adapt and add commands as needed for specific diagnostic scenarios.

## Elasticsearch API (via Console or Curl)
*Replace `<endpoint>` with `localhost:9200` or the appropriate cluster URL.*

### Cluster Health & Stability
- `GET /_cluster/health?pretty` (Overall status)
- `GET /_cluster/allocation/explain` (Why is a shard unassigned?)
- `GET /_cluster/settings?flat_settings&include_defaults` (Current settings)
- `GET /_cluster/state/master_node,nodes` (Master stability)

### Node & Resource Stats
- `GET /_cat/nodes?v&h=name,role,heap.percent,ram.percent,cpu,load_1m,node.role,master` (Node overview)
- `GET /_nodes/stats/jvm,fs,os,process?pretty` (Detailed resource usage)
- `GET /_nodes/hot_threads` (Identify CPU bottlenecks)
- `GET /_cat/thread_pool?v` (Queue buildup and rejections)

### Indices & Shards
- `GET /_cat/indices?v&s=docs.count:desc` (Index sizes and status)
- `GET /_cat/shards?v&s=state` (Shard distribution)
- `GET /_cat/recovery?v&active_only` (Ongoing recoveries)
- `GET /_cat/segments?v` (Segment count/memory)

### Curl Examples
- `curl -u <user>:<pass> -XGET "https://<endpoint>/_cluster/health?pretty" -k`
- `curl -u <user>:<pass> -XGET "https://<endpoint>/_cat/nodes?v"`

## Kubernetes & ECK
### Pod & Resource Status
- `kubectl get pods -n <namespace> -o wide`
- `kubectl describe pod <pod-name> -n <namespace>`
- `kubectl top pods -n <namespace>` (Requires metrics-server)
- `kubectl get events --sort-by=.metadata.creationTimestamp -n <namespace>`

### Logs & Debugging
- `kubectl logs -f <pod-name> -n <namespace> -c elasticsearch`
- `kubectl logs -f deployment/elastic-operator -n elastic-system` (ECK Operator logs)
- `kubectl exec -it <pod-name> -n <namespace> -- bash`

### ECK Custom Resources
- `kubectl get elasticsearch -n <namespace>`
- `kubectl get kibana -n <namespace>`
- `kubectl get beat -n <namespace>`
- `kubectl get agent -n <namespace>`
- `kubectl get pvc -n <namespace>` (Check volume binding)

## ECE Platform (Elastic Cloud Enterprise)
### Container Runtimes
#### Docker
- `docker ps -a`
- `docker logs <container>`
- `docker inspect <container>`
- `docker info`
- `systemctl status docker`
- `journalctl -u docker`

#### Podman
- `podman ps -a`
- `podman logs <container>`
- `podman inspect <container>`
- `podman info`
- `systemctl status podman`
- `journalctl -u podman`

### Infrastructure & Roles
- Check Allocator capacity: `df -h` on allocator hosts.
- Zookeeper health:
    - `echo ruok | nc <zookeeper-host> 2181`
    - `echo mntr | nc <zookeeper-host> 2181`
- Connectivity: `ss -lntp` (Check proxy/stunnel ports).

## OS / System / Networking
### Resource Pressure
- `df -h` / `df -i` (Disk space and inodes)
- `free -m` / `vmstat 1 5` (Memory and paging)
- `iostat -xz 1 5` (I/O wait and throughput)
- `top` / `uptime` (CPU load)
- `dmesg | tail -n 50` (Kernel errors/OOM kills)

### Networking & Connectivity
- `ss -lntp` / `netstat -tulpn` (Listening ports)
- `ip addr` / `ip route` (IP config)
- `cat /etc/resolv.conf` (DNS config)
- `openssl s_client -connect <endpoint>:<port> -showcerts` (TLS/Cert validation)
- `openssl x509 -in <cert> -noout -dates` (Expiry check)

### System Limits
- `ulimit -a` (Check `nofile`, `nproc`)
- `cat /proc/sys/vm/max_map_count` (Essential for Elasticsearch)

## Logstash / Kibana / Ingest
- `journalctl -u logstash` / `journalctl -u kibana`
- `tail -f /var/log/logstash/logstash-plain.log`
- `GET /_node/stats/pipelines` (Logstash pipeline stats)
- `GET /_ingest/pipeline` (List Elasticsearch ingest pipelines)
