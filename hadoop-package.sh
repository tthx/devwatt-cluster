#!/bin/bash
k8s-cmd "sudo apt-get -y install software-properties-common build-essential autoconf automake libtool cmake zlib1g-dev pkg-config libssl-dev libsasl2-dev ubuntu-snappy libsnappy-dev bzip2 libbz2-dev libjansson-dev fuse libfuse-dev zstd libzstd-dev yasm libatlas3-base libopenblas-base"
k8s-cmd "sudo rm /usr/lib/libblas.so /usr/lib/libblas.so.3 /usr/lib/liblapack.so /usr/lib/liblapack.so.3"
k8s-cmd "sudo ln -sf /usr/lib/x86_64-linux-gnu/atlas/libblas.so.3.10.3 /usr/lib/libblas.so"
k8s-cmd "sudo ln -sf /usr/lib/x86_64-linux-gnu/atlas/libblas.so.3.10.3 /usr/lib/libblas.so.3"
k8s-cmd "sudo ln -sf /usr/lib/x86_64-linux-gnu/atlas/liblapack.so.3.10.3 /usr/lib/liblapack.so"
k8s-cmd "sudo ln -sf /usr/lib/x86_64-linux-gnu/atlas/liblapack.so.3.10.3 /usr/lib/liblapack.so.3"