#!/bin/bash
# mysql -h 10.0.100.100 -P 4000 -u root --execute="create database sbtest;"
sysbench --config-file=config oltp_point_select --tables=32 --threads=32 --table-size=10000 prepare
