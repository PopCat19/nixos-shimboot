# lib/__init__.py

from lib.console import console, log_info, log_warn, log_error, log_success, log_step, log_section
from lib.mounts import mounted, chroot_bindings, MountError
from lib.system import ensure_root, detect_nixos_partition, get_hostname_from_rootfs
from lib.nix import (
    list_generations,
    find_nixos_configs,
    is_valid_config,
    get_flake_hostnames,
    infer_hostname_from_path,
    run_nixos_rebuild,
)
from lib.git_ops import (
    get_git_info,
    git_status_short,
    git_pull,
    git_stash_and_pull,
    git_pull_merge,
)
