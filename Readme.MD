# What?
Resources to run chaos tests

# Why?
Verify installation is resilient to outages

# How?
- Prerequisite: Kubernetes Cluster accessible via kubectl
- ```make chaos-mesh``` to install chaos-mesh
- ```make``` to startup camunda cluster with benchmark application to have constant load
- Run 1-N chaos experiments

# Setup
Resilient setup with 3 Brokers with 2 Gateways

# Experiments

## pod-kill
- pod-kill-1-broker = Killed Broker restarts and becomes follower (OK)
- pod-kill-1-gateway = Killed Gateway restarts (OK)
- pod-kill-elasticsearch = Killed ES restarts (OK)
- pod-kill-operate = Killed Operate restarts (OK)

## pod-failure
- pod-failure-1-broker = 1 Broker becomes unavailable and becomes follower (OK)
- pod-failure-1-gateway = 1 Gateway becomes unavailable and doesn't serve requests during that time (OK)
- pod-failure-elasticsearch = Elasticsearch becomes unavailable (NOK)
- pod-failure-operate = Operate Import Delay increases (NOK)

## network-delay
- network-delay-brokers = 250ms Delay in intra-brokers can increase processing time so much, that backpressure can be emitted. Inflight-requests are expected to increase (CHECK)
- network-delay-broker-to-elasticsearch = 5000ms Delay lead to increase in number of records not exported, Flush Duration and Flush Failure Rate. Also, Import Delay increases (NOK)
- network-delay-gateways-to-brokers = Delay from Gateway to Brokers doesn't have big impact (OK)
- network-delay-operate-to-elasticsearch = 2000ms Delay leads to increase in Import Time (and/or timeouts) (NOK)

## network-partition
- network-partition-1-broker-to-1-broker = OK
- network-partition-1-broker-to-all-brokers = 'Partitioned' Broker becomes Follower for all Partitions. 2 Remaining Brokers have Quorum and keep processing (OK)
- network-partition-all-brokers-to-all-brokers = Cluster becomes unavailable (NOK)
- network-partition-all-brokers-to-elasticsearch = Increase in number of records not exported and PVC Usage (NOK)

