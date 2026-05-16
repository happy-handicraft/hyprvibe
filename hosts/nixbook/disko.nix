# Declarative disk layout for nixbook (disko).
#
# Single-disk UEFI / systemd-boot install on /dev/sda:
#   GPT
#   ├─ part1  1 GiB  FAT32 ESP            -> /boot
#   ├─ part2  8 GiB  swap
#   └─ part3  rest   btrfs
#                     ├─ subvol @         -> /
#                     └─ subvol @home     -> /home
#
# This mirrors the original nixbook layout (btrfs @ + @home, vfat ESP,
# swap partition) but recreates it from scratch. disko also generates the
# fileSystems/swapDevices NixOS config, which is why those entries were
# removed from hardware-configuration.nix.
#
# Install from a live NixOS ISO (THIS ERASES /dev/sda):
#
#   git clone <this repo> && cd hyprvibe
#   nix flake lock                 # one-time: pins the new `disko` input
#   sudo nix --experimental-features "nix-command flakes" run \
#     github:nix-community/disko/latest -- \
#     --mode destroy,format,mount --flake .#nixbook --yes-wipe-all-disks
#   sudo nixos-install --flake .#nixbook
#   reboot
#
# If the target disk is not /dev/sda (e.g. /dev/nvme0n1), change
# `disko.devices.disk.main.device` below before running disko.
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/sda";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              priority = 1;
              type = "EF00";
              size = "1G";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [
                  "fmask=0077"
                  "dmask=0077"
                ];
              };
            };
            swap = {
              priority = 2;
              size = "8G";
              content = {
                type = "swap";
              };
            };
            root = {
              priority = 3;
              size = "100%";
              content = {
                type = "btrfs";
                # -f: force overwrite if a stale btrfs signature is present.
                extraArgs = [ "-f" ];
                subvolumes = {
                  "@" = {
                    mountpoint = "/";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                  "@home" = {
                    mountpoint = "/home";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
