#!/bin/bash
k8s-cmd "sudo apt-get -y install software-properties-common build-essential autoconf automake bison flex g++ git libevent-dev libtool cmake make zlib1g-dev pkg-config libssl-dev libsasl2-dev ubuntu-snappy libsnappy-dev bzip2 libbz2-dev libjansson-dev fuse libfuse-dev zstd libzstd-dev yasm libatlas3-base libopenblas-base r-base r-base-dev python3-pip python-pip pandoc-citeproc r-cran-knitr r-cran-rmarkdown r-cran-testthat r-cran-e1071 r-cran-survival texlive texlive-lang-french texlive-lang-english texlive-latex-extra"
k8s-cmd "sudo rm /usr/lib/libblas.so /usr/lib/libblas.so.3 /usr/lib/liblapack.so /usr/lib/liblapack.so.3"
k8s-cmd "sudo ln -sf /usr/lib/x86_64-linux-gnu/atlas/libblas.so.3.10.3 /usr/lib/libblas.so"
k8s-cmd "sudo ln -sf /usr/lib/x86_64-linux-gnu/atlas/libblas.so.3.10.3 /usr/lib/libblas.so.3"
k8s-cmd "sudo ln -sf /usr/lib/x86_64-linux-gnu/atlas/liblapack.so.3.10.3 /usr/lib/liblapack.so"
k8s-cmd "sudo ln -sf /usr/lib/x86_64-linux-gnu/atlas/liblapack.so.3.10.3 /usr/lib/liblapack.so.3"
