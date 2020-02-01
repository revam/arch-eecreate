# eecreate

Create bootable (U)EFI executables.

## Why?

Part of a bigger collection of scripts to contain a TPM-sealed LUKS-encrypted
startup process secured by Secure Boot, this script only create the (U)EFI
executable.

It was created to be flexible and scriptable:

- Only one task: turn kernel, ucode, initramfs and kernel cmdline into a
  bootable (U)EFI executable.
- By default esscalate to root user using sudo - or fail in
  the process - unless the '--no-root' option is supplied. Useful for humans,
  and can be disabled for machines.
- List possible kernel names to use with the 'list' command, and create (U)EFI
  executables with the 'create' command.
- Can use command line options or environment variables to customise inputs
  and output.
- Automatically finds the _most_ (subjective) optimal options for your  machine,
  but possible to manually override or disable the search for options on a per
  option basis.

## Install

### AUR

Coming soon™ to an AUR repository near you.

### Build from source

Steps to install manually:

1. Ensure dependenices are installed:

```sh
$ pacman -S bash binutils systemd
```

2. Copy `eecreate.sh` to `/usr/bin/eecreate`.

```sh
$ cp -T ./eecreate.sh /usr/bin/eecreate
```

3. Done!

## Related resources

- https://wiki.archlinux.org/index.php/EFISTUB#efibootmgr_with_.efi_file -
  booting from an efi file.
- https://github.com/xdever/arch-efiboot - simular project. Found out about
  it after creating this. Also a full solution to the "minimal" (U)EFI boot
  process, while this is only a single block in the process.