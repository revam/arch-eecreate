#!/bin/bash
#
# eecreate -- Create bootable (U)EFI-executables.
# Copyright (C) 2019-2020 Mikal Stordal <revam.noreply@user.revam.no>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

set -e

#region essential definitions

function not0or1() {
  if [[ "$1" =~ ^[01]$ ]]; then
    return 1
  fi
}

# Set essential variables if needed
if not0or1 "${QUIET}"; then
  QUIET=0
fi
if not0or1 "${VERBOSE}"; then
  VERBOSE=0
fi
if not0or1 "${NO_ROOT}": then
  NO_ROOT=0
fi

readonly VERSION="0.1.0"
readonly n=`basename "$0"`

# Log normal message
function log() {
  if ! (( QUIET )); then
    # More verbose log type
    if (( VERBOSE )); then
      echo "$n: log: $*" > /dev/stderr
    else
      echo "$*" > /dev/stderr
    fi
  fi
}

# (Conditionally) log extra messages
function verbose() {
  if (( VERBOSE )); then
    echo "$n: verbose: $*" > /dev/stderr
  fi
}

# Conditionally report error
function error() {
  if ! (( QUIET )); then
    # More verbose log type
    if (( VERBOSE )); then
      echo "$n: error: $*" > /dev/stderr
    else
      echo "$*" > /dev/stderr
    fi
  fi
}

# Conditionally report error
function warn() {
  if ! (( QUIET )); then
    # More verbose log type
    if (( VERBOSE )); then
      echo "$n: warning: $*" > /dev/stderr
    else
      echo "warning: $*" > /dev/stderr
    fi
  fi
}

# Conditionally report error and exit program
function panic() {
  error "$@"
  exit 1
}

# Ensure user is root (superuser) before proceeding
function ensure_root() {
  verbose "check if root"
  if [[ $UID -ne 0 ]]; then
    if (( NO_ROOT )); then
      verbose "user is ${USER:-not root}, but user want to continue."
      return 0
    fi
    verbose "trying to escalate privileges using sudo"
    exec sudo -u root "$0" "$@"
    exit 0
  fi
  verbose "user is root"
}

function assert_file() {
  verbose "$1: $2"
  if [[ -z "$2" ]]; then
    panic "$1 is empty"
  fi
  if [[ ! -r "$2" ]]; then
    panic "$2 does not exist"
  fi
}

#endregion essential definitions
#region main program

function main() {
  local COMMAND="$1"
  shift
  case $COMMAND in
    create | --create | -c)
      command_create "$@"
      ;;

    help | --help | -h)
      command_help "$@"
      ;;

    list | --list | -l)
      command_list "$@"
      ;;

    version | --version | -v)
      command_version "$@"
      ;;

    *)
      print_help
      ;;
  esac;
}

#endregion main program
#region help messages

function print_help() {
  cat > /dev/stderr <<HELPEOL
Usage: $0 <COMMAND>
  or:  $0 --version
  or:  $0 --help [COMMAND]

Create bootable (U)EFI-executables.

(User must be root or able to use sudo to execute some commands)

Commands:
  -v, --version, version      Print version and exit.
  -h, --help, help            Print help message and exit.

  -c, --create, create        Create EFI-executable and exit.
  -l, --list, list            Print list of available kernel names and exit.

HELPEOL
  exit 0
}

function print_help_for_create() {
  cat > /dev/stderr <<HELPEOL
Usage: [ENVIRONMENT...] $0 (create|--create|-c) [OPTION...] (--kernel <name>|<KERNELNAME>)
  or: KERNELNAME="<KERNELNAME>" [ENVIRONMENT...] $0 (create|--create|-c) [OPTION...]

Create a bootable (U)EFI-executable of the provided kernel, optional ucode, and
initramfs.

(User must be root or a able to use sudo to execute command, unless '--no-root'
is supplied)

Options:
  -h, --help                  Print this help message and exit.

  -v, --verbose               Turn on verbose logging. Toggles off
                              '--quiet' when set to on. Default is 'off'.
  -V, --no-verbose            Turn off verbose logging.

  -q, --quiet                 Suppress all output. Toggles off '--verbose' when
                              set to on. Default is 'off'.
  -Q, --no-quiet              Don't suppress output.

  -a, --arch <arch>           Spesify cpu architecture to create executable for.
                              Currently only one supported architecture, because
                              Arch Linux offically only support x86_64/amd64.

  -w, --vendor <vendor>       Spesify vendor for architecture to load ucode for.
                              (i.e. 'amd' or 'intel' for x86_64)

  -c, --cmdline <file>        Load kernel command-line from a spesified file.

  -s, --search-cmdline        Search for a file named
                              "cmdline-${KERNELNAME}.txt" or
                              "cmdline.default.txt" in /boot to load kernel
                              command-line from, and panic if no file exist.
  -S, --no-search-cmdline     Don't search for cmdline.

  -i, --initramfs <file>      Spesify initramfs to load. Deafult is to load
                              the image matching "initramfs-${KERNELNAME}.img"
                              in /boot.

  -j, --check-initramfs       Check initramfs (using lsinitcpio) for errors.
                              Default is 'on'.
  -J, --no-check-initramfs    Don't check initramfs for errors.

  -k, --kernel <name>         Spesify kernel name as an option and not an
                              argument.

  -o, --output <file>         Output destination. Default destination is
                              "${KERNELNAME}.efi" in current directory.

  -f, --force-output          Always override existing output destination.
                              Default is 'off'.
  -F, --no-force-output       Don't force output, prompt user for confimation if
                              needed.

  -u, --ucode <file>          Alternate microcode (ucode) for CPU to load before
                              the initramfs.

  -t, --search-ucode          Search for microcode (ucode) based on cpu arch. and
                              cpu vendor.
                              Default is 'on'
  -T, --no-search-ucode       Don't search for ucode.

      --no-root               Don't escalate to root, and try to run as current
                              user. No garantees given.

Environment variables:
  VERBOSE                     Possible values are '0' or '1', anything else will
                              result in the default value be used instead.
                              Corresponds to option '--verbose' listed above.
  QUIET                       Possible values are '0' or '1', anything else will
                              result in the default value be used instead.
                              Corresponds to option '--quiet' listed above.
  ARCH                        Corresponds to '--arch'.
  CMDLINE                     Corresponds to '--cmdline'.
  INITRAMFS                   Corresponds to '--initramfs'.
  KERNEL                      Corresponds to '--kernel.
  OUTPUT                      Corresponds to '--output'.
  UCODE                       Corresponds to '--ucode'.
  VENDOR                      Corresponds to '--vendor'.
  NO_ROOT                     Possible values are '0' or '1', anything else will
                              result in the default value be used instead.
                              Corresponds to option '--no-root' listed above.

Option take precedence if a corresponding environment variable is also supplied.

Examples:
  # Create an executeable named '4.0-x86_64.efi' in the current working directory.
  $n -e 4.0-x86_64

  # Replace a existing boot entry while searching the /boot directory for command-line options.
  $n -e 4.0-x86_64 -o /efi/EFI/BOOT/BOOTX64.efi

  # Create a default boot entry with supplied kernel command-line options.
  $n -e -k 4.0-x86_64 -c /boot/cmdline.custom.txt -o /efi/EFI/BOOT/BOOTX64.efi

HELPEOL
  exit 0
}

function print_help_for_help() {
  cat > /dev/stderr <<HELPEOL
Usage: $0 (help|--help|-h) [subcommand]

Print help message for main program or sub-command and exit.

Examples:
  # Print help message for main program
  $n help

  # Print help message for subcommand 'list'
  $n help list

HELPEOL
  exit 0
}

function print_help_for_list() {
  cat > /dev/stderr <<HELPEOL
Usage: $0 (list|--list|-l) [OPTION]...

List possible kernels to build EFI-executables for.

(User must be root or a able to use sudo to execute command, unless '--no-root'
is supplied)

Options:
  -h, --help                  Print this help message and exit.

  -v, --verbose               Turn on verbose logging. Toggles off
                              '--quiet' when set to on. Default is 'off'.
  -V, --no-verbose            Turn off verbose logging.

  -q, --quiet                 Suppress all output. Toggles off '--verbose' when
                              set to on. Default is 'off'.
  -Q, --no-quiet              Don't suppress output.

      --no-root               Don't escalate to root, and try to run as current
                              user. No garantees given.

Environment variables:
  VERBOSE                     Possible values are '0' or '1', anything else will
                              result in the default value be used instead.
                              Corresponds to option '--verbose' listed above.
  QUIET                       Possible values are '0' or '1', anything else will
                              result in the default value be used instead.
                              Corresponds to option '--quiet' listed above.
  NO_ROOT                     Possible values are '0' or '1', anything else will
                              result in the default value be used instead.
                              Corresponds to option '--no-root' listed above.

Option take precedence if a corresponding environment variable is also supplied.

Examples:
  # Print executables and exit.
  $n list

HELPEOL
  exit 0
}

function print_help_for_version() {
  cat > /dev/stderr <<HELPEOL
Usage: $0 (version|--version|-v) [-h|--help]

Print version and exit.

Options:
  -h, --help                  Print this help message and exit.

HELPEOL
  exit 0
}


#endregion help messages
#region sub-command routines

# Create executable and exit.
function command_create() {
  parse_args_for_create "$@"

  if [[ -z "${KERNEL}" ]]; then
    print_help_for_create
  fi
  ensure_root "-c" "$@"
  if [[ -z "${KERNEL}" ]]; then
    error "kernel not spesified"
    print_help_for_create
  fi

  local kernel_file="/boot/vmlinuz-${KERNEL}"
  assert_file "kernel" "${kernel_file}"

  local arch="${ARCH:-$(uname -m)}"
  # Find vendor id of first logical cpu core in /proc/cpuinfo
  local vendor="${VENDOR:-$(cat /proc/cpuinfo | grep vendor_id | head -n1 | cut -f2 | tail -c+3)}"
  verbose "cpu architecture: ${arch}"
  verbose "cpu vendor: ${vendor}"

  # Find the systemd EFI-stub
  local efistub_file
  case $arch in
    x86_64 | amd64)
      efistub_file="/usr/lib/systemd/boot/efi/linuxx64.efi.stub"
      ;;
    # TODO: Add more supported architectures here
    *)
      panic "unsupported cpu architecture"
      ;;
  esac
  assert_file "efi stub" "${efistub_file}"

  # handle ucode updates for Intel/AMD CPUs, or custom image spesified
  # through env. var. or command option
  local ucode_file="${UCODE}"
  if [[ -z $ucode_file ]]; then
    if (( SEARCH_UCODE )); then
      verbose "search for ucode"
      case $arch in
        x86_64 | amd64)
          case $vendor in
            amd | AuthenticAMD)
              ucode_file="/boot/amd-ucode.img"
              ;;
            intel | GenuineIntel)
              ucode_file="/boot/intel-ucode.img"
              ;;
            *)
              panic "unsupported cpu vendor"
              ;;
          esac
          ;;
        # TODO: Add more architectures/vendors here
        *)
          panic "unsupported cpu architecture"
          ;;
        esac
    else
      verbose "skip: search for ucode"
      ucode_file="/dev/null"
    fi
  fi
  assert_file "ucode" "${ucode_file}"

  local cmdline_file="${CMDLINE}"
  if [[ -z "${cmdline_file}" ]]; then
    if (( SEARCH_CMDLINE )); then
      verbose "search for cmdline"
      for file in "/boot/cmdline-${KERNEL}.txt" "/boot/cmdline.txt"; do
        if [[ -f "$file" && -r "$file" ]]; then
          cmdline_file="$file"
          break
        fi
      done
      if [[ -z "${cmdline_file}" ]]; then
        warn "Unable to find cmdline file(s). A possible fix is to create either '/boot/cmdline.txt' or '/boot/cmdline-${KERNEL}.txt'. Disable this warning by supplying '--no-search-cmdline' or '-S' on next run."
      fi
    else
      verbose "skip: search for cmdline"
      cmdline_file="/dev/null"
    fi
  fi
  assert_file "cmdline" "${cmdline_file}"

  local initramfs_file="${INITRAMFS:-/boot/initramfs-${KERNEL}.img}"
  assert_file "initramfs" "${initramfs_file}"
  if (( CHECK_INITRAMFS )); then
    verbose "check initramfs"
    # Check if $initrd (exists and) is a valid image
    if ! lsinitcpio -a "${initramfs_file}" >> /dev/null; then
    	panic "unable to analyse initial ramdisk filesystem"
    fi
  else
    verbose "skip: check initramfs"
  fi

  # Output file
  local output_file="${OUTPUT:-${KERNEL}.efi}"
  verbose "output: ${output_file}"
  # Check if we should prompt user for confirmation before proceeding
  if [[ -r $output_file ]] && ! (( FORCE_OUTPUT )); then
    local REPLY
    verbose "output exists and not forcing, so ask user for confirmation"
    read -p "override ${output_file}? [yN] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      verbose "aborted."

      return 1
    fi
  fi

  # create (and delete) temporary files
  local early_userspace_file="$(mktemp)"
  trap 'rm -f "${early_userspace_file}"' EXIT

  # Combine ucode blob and initramfs blob into early-userspace blob. Refer to:
  # - https://www.kernel.org/doc/Documentation/early-userspace/buffer-format.txt
  # - https://www.kernel.org/doc/Documentation/x86/early-ucode.txt
  # for more info.
  cat "${ucode_file}" "${initramfs_file}" > "${early_userspace_file}"

  local directory=`dirname ${output_file}`
  verbose "ensure directory '${directory}' exists"
  mkdir -p "${directory}"

  # Create a combined binary with systemd EFI stub. For additional information see:
  # - https://github.com/systemd/systemd/blob/master/src/boot/efi/stub.c
  # - https://github.com/systemd/systemd/blob/master/test/test-efi-create-disk.sh
  verbose "create ${output_file}"
  objcopy \
    --add-section .osrel="/etc/os-release" --change-section-vma .osrel=0x20000    \
    --add-section .cmdline="${cmdline_file}" --change-section-vma .cmdline=0x30000  \
    --add-section .linux="${kernel_file}" --change-section-vma .linux=0x2000000  \
    --add-section .initrd="${early_userspace_file}" --change-section-vma .initrd=0x3000000 \
    "${efistub_file}" "${output_file}"
  log "created ${output_file}"

  exit 0
}

# Print help for main program or sub-command and exit.
function command_help() {
  local WANT_HELP=1
  local HELP_FUNCTION="print_help"
  while [[ -n "$1" ]]; do case $1 in
    create | --create | -e)
      if (( WANT_HELP )); then
        HELP_FUNCTION=print_help_for_create
        WANT_HELP=0
      fi
      ;;

    help | --help | -h)
      if (( WANT_HELP )); then
        HELP_FUNCTION=print_help_for_help
        WANT_HELP=0
      fi
      ;;

    list | --list | -l)
      if (( WANT_HELP )); then
        HELP_FUNCTION=print_help_for_list
        WANT_HELP=0
      fi
      ;;

    version | --version | -v)
      if (( WANT_HELP )); then
        HELP_FUNCTION=print_help_for_version
        WANT_HELP=0
      fi
      ;;

    *)
      error "unknown option or argument '$1'."
      HELP_FUNCTION=print_help_for_help
      WANT_HELP=0
      ;;
  esac; shift; done
  $HELP_FUNCTION
}

# List usable kernel names and exit.
function command_list() {
  parse_args_for_list "$@"
  # check if user can access boot, and MAYBE escalate access level.
  if [[ ! -r "/boot" ]]; then
    ensure_root "-l" "$@"
  fi
  all_kernels=(/boot/vmlinuz-*)
  all_kernels=("${all_kernels[@]#/boot/vmlinuz-}")
  echo "${all_kernels[@]}"
  exit 0
}

# Print version and exit.
function command_version() {
  parse_args_version "$@"
  echo -n "${VERSION}"
  exit 0
}

#endregion sub-command routines
#region argument and option parsing

# Parse arguments and set environment variables
function parse_args_for_create() {
  # Some arguments are lazy-initialised to allow passing in from environment
  # variables.
  # ARCH=""
  local ARG=()
  CHECK_INITRAMFS=1
  # CMDLINE=""
  FORCE_OUTPUT=0
  # INITRAMFS=""
  # KERNEL=""
  # NO_ROOT=0 # Sourced from common
  # OUTPUT=""
  # QUIET=0 # Sourced from common
  SEARCH_CMDLINE=1
  SEARCH_UCODE=1
  # UCODE=""
  # VERBOSE=0 # Sourced from common
  # VENDOR=""

  local NEED_HELP=0

  while [[ -n "$1" && "$1" != "--" ]]; do case $1 in
    -h | --help)
      NEED_HELP=1
      ;;

    -q | --quiet)
      QUIET=1
      VERBOSE=0
      ;;

    -Q | --no-quiet)
      QUIET=0
      ;;

    -v | --verbose)
      QUIET=0
      VERBOSE=1
      ;;

    -V | --no-verbose)
      VERBOSE=0
      ;;

    -f | --force-output)
      FORCE_OUTPUT=1
      ;;

    -F | --no-force-output)
      FORCE_OUTPUT=0
      ;;

    -a | --arch)
      local option=$1
      shift
      if [[ -z "$1" || "$1" =~ ^- ]]; then
        panic "$option: value must be spesified"
      fi
      ARCH="$1"
      ;;

    --vendor)
      local option=$1
      shift
      if [[ -z "$1" || "$1" =~ ^- ]]; then
        panic "$option: value must be spesified"
      fi
      VENDOR="$1"
      ;;


    -c | --cmdline)
      local option=$1
      shift
      # NO option was spesified, we will search later
      if [[ -z "$1" || "$1" =~ ^- ]]; then
        panic "$option: value must be spesified"
      fi
      CMDLINE="$1"
      SEARCH_CMDLINE=0
      ;;

    -s | --search-cmdline)
      CMDLINE=""
      SEARCH_CMDLINE=1
      ;;

    -S | --no-search-cmdline)
      SEARCH_CMDLINE=0
      ;;

    -i | --initramfs)
      local option=$1
      shift
      if [[ -z "$1" || "$1" =~ ^- ]]; then
        panic "$option: value must be spesified"
      fi
      if [[ ! -r "$1" ]]; then
        panic "$1 does not exist"
      fi
      INITRAMFS="$1"
      ;;

    -j | --check-initramfs)
      CHECK_INITRAMFS=1
      ;;

    -J | --no-check-initramfs)
      CHECK_INITRAMFS=0
      ;;

    -k | --kernel)
      local option=$1
      shift
      if [[ -z "$1" || "$1" =~ ^- ]]; then
        panic "$option: value must be spesified"
      fi
      KERNEL="$1"
      ;;

    -o | --output)
      local option=$1
      shift
      if [[ -z "$1" || "$1" =~ ^- ]]; then
        panic "$option: value must be spesified"
      fi
      OUTPUT="$1"
      ;;

    -u | --ucode)
      local option=$1
      shift
      if [[ -z "$1" || "$1" =~ ^- ]]; then
        panic "$option: value must be spesified"
      fi
      if [[ ! -r "$1" ]]; then
        panic "$1 does not exist"
      fi
      UCODE="$1"
      SEARCH_UCODE=0
      ;;

    -t | --search-for-ucode)
      UCODE=""
      SEARCH_UCODE=1
      ;;

    -T | --no-search-for-ucode)
      SEARCH_UCODE=0
      ;;

    --no-root)
      NO_ROOT=1
      ;;

    *)
      # Argument
      if [[ ! "$1" =~ ^- ]]; then
        ARG+=("$1")
      # Unknown option
      else
        error "unknown option '$1'."
        NEED_HELP=1
      fi
      ;;
  esac; shift; done

  if (( NEED_HELP )); then
    print_help_for_create
  fi

  if [[ "$1" == '--' ]]; then
    shift;
    ARG+=("$@")
  fi

  if [[ -z "${KERNELNAME}" && ( "${#ARG[@]}" -ge 1 && -n "${ARG[0]}" ) ]]; then
    KERNEL="${ARG[0]}"
  fi

  readonly ARCH CHECK_INITRAMFS CMDLINE FORCE_OUTPUT INITRAMFS KERNEL LIST OUTPUT QUIET SEARCH_CMDLINE SEARCH_UCODE UCODE VENDOR VERBOSE
}

function parse_args_for_list() {
  local NEED_HELP=0
  # NO_ROOT=0 # Sourced from common
  # QUIET=0 # Sourced from common
  # VERBOSE=0 # Sourced from common
  while [[ -n "$1" ]]; do case $1 in
    -h | --help)
      NEED_HELP=1
      ;;

    -q | --quiet)
      QUIET=1
      VERBOSE=0
      ;;

    -Q | --no-quiet)
      QUIET=0
      ;;

    -v | --verbose)
      QUIET=0
      VERBOSE=1
      ;;

    -V | --no-verbose)
      VERBOSE=0
      ;;

    --no-root)
      NO_ROOT=1
      ;;

    *)
      error "unknown argument or option '$1'."
      NEED_HELP=1
      ;;
  esac; shift; done

  if (( NEED_HELP )); then
    print_help_for_list
  fi
}

function parse_args_version() {
  local NEED_HELP=0
  while [[ -n "$1" ]]; do case $1 in
    *)
      error "unknown argument or option '$1'."
      ;&

    -h | --help)
      NEED_HELP=1
      ;;
  esac; shift; done

  if (( NEED_HELP )); then
    print_help_for_version
  fi
}

#endregion argument and option parsing

main "$@"
