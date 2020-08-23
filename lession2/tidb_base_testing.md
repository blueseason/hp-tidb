
# TiDB Base Testing
## Base Testing 背景知识
1. [用 TiUP 部署 TiDB 集群]( https://docs.pingcap.com/zh/tidb/stable/production-deployment-using-tiup)
2. [TiKV 线程池优化](https://github.com/pingcap-incubator/tidb-in-action/blob/master/session4/chapter8/threadpool-optimize.md)
3. [PD Dashboard 说明](https://docs.pingcap.com/zh/tidb/stable/dashboard-intro)
4. [TPCC 背景知识](https://github.com/pingcap-incubator/tidb-in-action/blob/master/session4/chapter3/tpc-c.md)
5. [ycsb,sysbench](https://github.com/pingcap-incubator/tidb-in-action/blob/master/session4/chapter3/sysbench.md)

## 搭建测试环境

在单机上可以利用vitualbox, vagrant自动部署多台虚拟机供测试环境使用，virtualbox和vagrant安装比较简单，这里不再赘述。

本机的配置为intel i7 8750H 6 core, 16gb, wd blue 500gb ssd

拓扑结构如以下
- TiDB 1台，每台配置 1 core 2GB
- TiKV 3台，每台配置 1 core 2GB
- PD   1台，每台配置 1 core 2GB


vagrant file 如下
```
ENV["LC_ALL"] = "en_US.UTF-8"

Vagrant.configure("2") do |config|
  config.vm.box = "season/bionic64-base"
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "2048"
  end

  config.ssh.username = "devops"
  #config.ssh.password = "vagrant"
  #config.ssh.keys_only = "false"
  #config.ssh.private_key_path = "/home/season/.ssh/id_rsa"

  # tidb
  config.vm.define "tidb" do |guest|
    guest.vm.hostname = "tidb"
    guest.vm.network "private_network", ip: "10.0.100.100"
  end

  config.vm.define "pd" do |guest|
    guest.vm.hostname = "pd"
    guest.vm.network "private_network", ip: "10.0.100.101"
  end

  # tikv node 1,2,3
  (3..5).each do |i|

    config.vm.define "tikv#{i-2}" do |node|
      node.vm.hostname = "tikv#{i-2}"
      node.vm.network "private_network", ip: "10.0..100.#{i+100}"
    end
  end

end
```

运行vagrant up 启动虚拟机，vagrant status 查看状态
```
Current machine states:

tidb                      running (virtualbox)
pd                        running (virtualbox)
tikv1                     running (virtualbox)
tikv2                     running (virtualbox)
tikv3                     running (virtualbox)


```


tidb cluster 配置文件如下
```
# # Global variables are applied to all deployments and used as the default value of
# # the deployments if a specific deployment value is missing.
global:
  user: "tidb"
  ssh_port: 22
  deploy_dir: "/tidb-deploy"
  data_dir: "/tidb-data"

# # Monitored variables are applied to all the machines.
monitored:
  node_exporter_port: 9100
  blackbox_exporter_port: 9115
  # deploy_dir: "/tidb-deploy/monitored-9100"
  # data_dir: "/tidb-data/monitored-9100"
  # log_dir: "/tidb-deploy/monitored-9100/log"

# # Server configs are used to specify the runtime configuration of TiDB components.
# # All configuration items can be found in TiDB docs:
# # - TiDB: https://pingcap.com/docs/stable/reference/configuration/tidb-server/configuration-file/
# # - TiKV: https://pingcap.com/docs/stable/reference/configuration/tikv-server/configuration-file/
# # - PD: https://pingcap.com/docs/stable/reference/configuration/pd-server/configuration-file/
# # All configuration items use points to represent the hierarchy, e.g:
# #   readpool.storage.use-unified-pool
# #      
# # You can overwrite this configuration via the instance-level `config` field.

server_configs:
  tidb:
    log.slow-threshold: 300
    binlog.enable: false
    binlog.ignore-error: false
  tikv:
    # server.grpc-concurrency: 4
    # raftstore.apply-pool-size: 2
    # raftstore.store-pool-size: 2
    # rocksdb.max-sub-compactions: 1
    # storage.block-cache.capacity: "16GB"
    # readpool.unified.max-thread-count: 12
    readpool.storage.use-unified-pool: false
    readpool.coprocessor.use-unified-pool: true
  pd:
    schedule.leader-schedule-limit: 4
    schedule.region-schedule-limit: 2048
    schedule.replica-schedule-limit: 64

pd_servers:
  - host: 10.0.100.101
    # ssh_port: 22
    # name: "pd-1"
    # client_port: 2379
    # peer_port: 2380
    # deploy_dir: "/tidb-deploy/pd-2379"
    # data_dir: "/tidb-data/pd-2379"
    # log_dir: "/tidb-deploy/pd-2379/log"
    # numa_node: "0,1"
    # # The following configs are used to overwrite the `server_configs.pd` values.
    # config:
    #   schedule.max-merge-region-size: 20
    #   schedule.max-merge-region-keys: 200000


tidb_servers:
  - host: 10.0.100.100
    # ssh_port: 22
    # port: 4000
    # status_port: 10080
    # deploy_dir: "/tidb-deploy/tidb-4000"
    # log_dir: "/tidb-deploy/tidb-4000/log"
    # numa_node: "0,1"
    # # The following configs are used to overwrite the `server_configs.tidb` values.
    # config:
    #   log.slow-query-file: tidb-slow-overwrited.log


tikv_servers:
  - host: 10.0.100.103
    # ssh_port: 22
    # port: 20160
    # status_port: 20180
    # deploy_dir: "/tidb-deploy/tikv-20160"
    # data_dir: "/tidb-data/tikv-20160"
    # log_dir: "/tidb-deploy/tikv-20160/log"
    # numa_node: "0,1"
    # # The following configs are used to overwrite the `server_configs.tikv` values.
    # config:
    #   server.grpc-concurrency: 4
    #   server.labels: { zone: "zone1", dc: "dc1", host: "host1" }
  - host: 10.0.100.104
  - host: 10.0.100.105

monitoring_servers:
  - host: 10.0.100.101
    # ssh_port: 22
    # port: 9090
    # deploy_dir: "/tidb-deploy/prometheus-8249"
    # data_dir: "/tidb-data/prometheus-8249"
    # log_dir: "/tidb-deploy/prometheus-8249/log"

grafana_servers:
  - host: 10.0.100.101
    # port: 3000
    # deploy_dir: /tidb-deploy/grafana-3000

alertmanager_servers:
  - host: 10.0.100.101
    # ssh_port: 22
    # web_port: 9093
    # cluster_port: 9094
    # deploy_dir: "/tidb-deploy/alertmanager-9093"
    # data_dir: "/tidb-data/alertmanager-9093"
    # log_dir: "/tidb-deploy/alertmanager-9093/log"
```

TiUP 部署集群
```
 tiup cluster deploy tidb-benchmark nightly ./complex-mini.yaml --user devops

```
集群拓扑截图


启动TiDB集群
```
tiup cluster start tidb-benchmark

mysql -h 10.0.100.100 -P 4000 -u root

show databases;

create database benchmark;

```

## Sysbench 测试

ubuntu 安装
```
curl -s https://packagecloud.io/install/repositories/akopytov/sysbench/script.deb.sh | sudo bash
sudo apt -y install sysbench
```
