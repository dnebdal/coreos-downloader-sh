# coreos-downloader-sh
A shell script to download the latest Fedora CoreOS for any platform.

Fedora provides [CoreOS Installer](https://coreos.github.io/coreos-installer/), but that requires 200+ Rust packages, multiple of which are Linux-only.
As of March 2025 they also do not provide a stable "latest" URL, since they want people to use their tool.

This script should work anywhere with a Bourne style shell, a download tool (wget, curl, fetch), [jq](https://jqlang.org/), and sha256sum.

Example usage:

```
$ ./get_coreos.sh list-arch
stable.json                                             54 kB 2262 kBps    00s
aarch64
ppc64le
s390x
x86_64
$ ./get_coreos.sh list-formats s390x
stable.json                                             54 kB   13 MBps    00s
  ibmcloud	qcow2.xz
     metal	4k.raw.xz
     metal	iso
     metal	pxe
     metal	raw.xz
 openstack	qcow2.xz
      qemu	qcow2.xz
$ ./get_coreos.sh get s390x metal pxe
stable.json                                             54 kB   32 MBps    00s
>> initramfs
fedora-coreos-41.20250215.3.0-live-initramfs.s          56 MB   27 MBps    02s
Checksums match
>> kernel
fedora-coreos-41.20250215.3.0-live-kernel-s390          13 MB   15 MBps    01s
Checksums match
>> rootfs
fedora-coreos-41.20250215.3.0-live-rootfs.s390         549 MB   34 MBps    16s
Checksums match
$ 
```
