# QTS as a VM

## How to use

1. Make sure you have make, curl, dd, OpenSSH (client) and avahi (client) installed.
2. Make sure you have a QNAP NAS logged in to your network that you can log in to via SSH as `admin` user.
3. Run `make boot.img` to compile a raw bootable image. It will try and download necessary tools like SC1 off your NAS and the firmware will be downloaded from QNAP's server.
4. (optional:) Run `make boot.vmdk` instead to get a VMware image. You will need qemu-img installed for this.

## Known issues

- The GRUB version used is extremely old (from 2010) and I need to find a way to
  compile it from source so it can be recreated entirely without relying on
  dumped files. I don't think this represents an issue at the moment.
- The created image will boot up to `hal_boot start` and then stay there. I
  suspect some incompatible VM hardware configuration is causing this. This happens on both VMware and QEMU.
