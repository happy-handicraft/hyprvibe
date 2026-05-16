# nixbook — disko install guide

Declarative disk setup + install for the `nixbook` host using
[disko](https://github.com/nix-community/disko).

The layout lives in [`hosts/nixbook/disko.nix`](../hosts/nixbook/disko.nix)
and is wired into the `nixbook` flake config, so disko also generates the
`fileSystems` / `swapDevices` NixOS config (those entries were removed from
`hardware-configuration.nix`).

## Disk layout (single UEFI disk, default `/dev/sda`)

```
GPT
├─ part1  1 GiB  FAT32 ESP        -> /boot
├─ part2  8 GiB  swap
└─ part3  rest   btrfs
                  ├─ subvol @     -> /
                  └─ subvol @home -> /home
```

If the target disk is **not** `/dev/sda` (e.g. NVMe is `/dev/nvme0n1`),
edit `disko.devices.disk.main.device` in `hosts/nixbook/disko.nix` before
running disko. ESP (1 GiB) and swap (8 GiB) sizes are adjustable in the
same file.

## Install from a live NixOS ISO

> **Warning:** step 4 destroys all data on the target disk.

```sh
# 0. Boot the NixOS live ISO, get a root shell + network
sudo -i

# 1. Get the repo
nix-shell -p git --run 'git clone https://github.com/happy-handicraft/hyprvibe'
cd hyprvibe
git checkout claude/add-disko-config-wCwTN

# 2. Lock the disko flake input (one-time)
nix --experimental-features "nix-command flakes" flake lock

# 3. (optional) sanity-check the flake evaluates
nix --experimental-features "nix-command flakes" flake check

# 4. Partition + format + mount the disk (DESTROYS the target disk)
nix --experimental-features "nix-command flakes" run \
  github:nix-community/disko/latest -- \
  --mode destroy,format,mount --flake .#nixbook --yes-wipe-all-disks

# 5. Verify the mounts under /mnt
mount | grep /mnt
# expect: btrfs @ on /mnt, @home on /mnt/home, vfat on /mnt/boot, swap active

# 6. Install (set the root password when prompted)
nixos-install --flake .#nixbook

# 7. Reboot into the new system
reboot
```

## Day-to-day, on the installed system

```sh
# rebuild after editing config
sudo nixos-rebuild switch --flake /path/to/hyprvibe#nixbook

# re-run just the disko layout (rare; destroys data)
sudo nix run github:nix-community/disko/latest -- \
  --mode destroy,format,mount --flake .#nixbook --yes-wipe-all-disks
```
