#!/bin/bash

sudo dnf clean all

sudo dnf group list --verbose | tee "$1.dnf.group.list.out"
for opt in enabled disabled installed available all
do
  sudo dnf module list --"${opt}" | tee "$1.dnf.module.list.$opt.out"
done

rpm -qa | sort | tee "$1.packages.out"

rpm -qa --queryformat="%{NAME},%{EPOCH},%{VERSION},%{RELEASE},%{ARCH}\n" | sort | tee "$1.packages.nevra.out"

lsblk | tee "$1.lsblk.out"

