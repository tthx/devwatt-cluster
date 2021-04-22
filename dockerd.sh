#!/bin/bash
sudo systemctl stop docker && \
sudo systemctl stop docker.socket && \
sudo systemctl start docker.socket && \
sudo systemctl start docker