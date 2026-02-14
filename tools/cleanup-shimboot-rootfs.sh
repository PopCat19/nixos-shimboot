#!/usr/bin/env bash

# cleanup-shimboot-rootfs.sh
#
# Purpose: Safely prune old shimboot rootfs generations without touching other outputs
#
# This module:
# - Discovers rootfs store paths via profiles, GC roots, or repo symlinks
# - Identifies candidates matching the pattern and keeps the newest N
# - Deletes older generations avoiding global GC

set -Eeuo pipefail
ANSI_CLEAR='\033[0m'
ANSI_BOLD='\033[1m'
ANSI_GREEN='\033[1;32m'
ANSI_BLUE='\033[1;34m'
ANSI_YELLOW='\033[1;33m'
ANSI_RED='\033[1;31m'

log_info() { printf "${ANSI_BLUE}[INFO]${ANSI_CLEAR} %s\n" "$*" >&2; }
log_warn() { printf "${ANSI_YELLOW}[WARN]${ANSI_CLEAR} %s\n" "$*" >&2; }
log_error() { printf "${ANSI_RED}[ERROR]${ANSI_CLEAR} %s\n" "$*" >&2; }
log_success() { printf "${ANSI_GREEN}[SUCCESS]${ANSI_CLEAR} %s\n" "$*" >&2; }

KEEP=1
DRY_RUN=1
PROFILE=""
GCROOTS=""
RESULTS_DIR="$(pwd)"
PATTERN="-nixos-disk-image"
REMOVE_STALE_SYMLINKS=0

usage() {
	cat <<'EOF'
Usage: cleanup-shimboot-rootfs.sh [options]

Options:
  -k, --keep N                  Number of newest generations to keep (default: 1)
  -n, --dry-run                 Do not perform deletions (default)
      --no-dry-run             Perform deletions
  -p, --profile PATH            Nix profile that tracks shimboot generations
  -g, --gcroots PATH            Directory containing GC root symlinks for shimboot
  -r, --results-dir PATH        Directory to scan for "result*" symlinks (default: current repo)
  -m, --match-substr SUBSTR     Substring to identify rootfs store paths (default: "-nixos-disk-image")
      --remove-stale-symlinks   Remove repo "result*" symlinks that point to deleted store paths
  -h, --help                    Show this help

Discovery priority:
  1) --profile if provided
  2) --gcroots if provided
  3) --results-dir result* symlinks

Only rootfs-like store paths (matching -m/--match-substr) are considered for deletion.
EOF
}

# Parse args
while [[ $# -gt 0 ]]; do
	case "$1" in
	-k | --keep)
		KEEP="${2:-}"
		[[ -n "$KEEP" ]] || {
			log_error "Missing value for --keep"
			exit 2
		}
		shift 2
		;;
	-n | --dry-run)
		DRY_RUN=1
		shift
		;;
	--no-dry-run)
		DRY_RUN=0
		shift
		;;
	-p | --profile)
		PROFILE="${2:-}"
		[[ -n "$PROFILE" ]] || {
			log_error "Missing value for --profile"
			exit 2
		}
		shift 2
		;;
	-g | --gcroots)
		GCROOTS="${2:-}"
		[[ -n "$GCROOTS" ]] || {
			log_error "Missing value for --gcroots"
			exit 2
		}
		shift 2
		;;
	-r | --results-dir)
		RESULTS_DIR="${2:-}"
		[[ -n "$RESULTS_DIR" ]] || {
			log_error "Missing value for --results-dir"
			exit 2
		}
		shift 2
		;;
	-m | --match-substr)
		PATTERN="${2:-}"
		[[ -n "$PATTERN" ]] || {
			log_error "Missing value for --match-substr"
			exit 2
		}
		shift 2
		;;
	--remove-stale-symlinks)
		REMOVE_STALE_SYMLINKS=1
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		log_error "Unknown argument: $1"
		usage
		exit 2
		;;
	esac
done

# Ensure numeric KEEP
if ! [[ "$KEEP" =~ ^[0-9]+$ ]]; then
	log_error "--keep must be an integer"
	exit 2
fi

# Resolve a path (follows symlinks once)
resolve_path() {
	local p="$1"
	if command -v readlink >/dev/null 2>&1; then
		readlink -f -- "$p" 2>/dev/null || true
	else
		# Fallback: best effort
		python - <<'EOF' 2>/dev/null || true
import os,sys
p=sys.argv[1]
try:
  print(os.path.realpath(p))
except Exception:
  pass
EOF
		"$p"
	fi
}

# Returns 0 if given path looks like a rootfs store dir (directory under /nix/store with expected pattern)
is_rootfs_store_dir() {
	local store_dir="$1"
	[[ -n "$store_dir" ]] || return 1
	[[ "$store_dir" == /nix/store/* ]] || return 1
	# Dir name must include pattern substring
	if [[ "$(basename -- "$store_dir")" == *"$PATTERN"* ]]; then
		return 0
	fi
	return 1
}

# If given a file under a store dir (like ...-nixos-disk-image/nixos.img),
# return the parent store dir; else return input if it's already a store dir.
store_dir_of() {
	local p="$1"
	[[ -n "$p" ]] || {
		echo ""
		return
	}
	local rp
	rp="$(resolve_path "$p")"
	[[ -n "$rp" ]] || {
		echo ""
		return
	}
	if [[ "$rp" == /nix/store/*/* ]]; then
		# Likely a file within a store dir
		dirname -- "$rp"
	else
		echo "$rp"
	fi
}

# Discover candidates from a profile
discover_via_profile() {
	local profile="$1"
	[[ -e "$profile" ]] || return 0

	# Prefer nix profile (flakes) listing if available; else nix-env
	if command -v nix >/dev/null 2>&1; then
		# nix profile list -p requires flakes profiles; fallback to nix-env parsing otherwise.
		:
	fi

	if command -v nix-env >/dev/null 2>&1; then
		# nix-env --list-generations does not always show out-paths; derive via profile symlinks
		# Examine "$profile"-<gen>-link symlinks ordered by gen number.
		local pfdir pbase
		pfdir="$(dirname -- "$profile")"
		pbase="$(basename -- "$profile")"
		# Symlinks look like /nix/var/nix/profiles/shimboot-123-link
		# shellcheck disable=SC2012
		ls -1 "${pfdir}/${pbase}-"*"-link" 2>/dev/null | sed -E 's/.*-([0-9]+)-link$/\1\t&/' | sort -k1,1n | while IFS=$'\t' read -r gen path; do
			local target
			target="$(resolve_path "$path")"
			# target is the generation root; scan for children that look like rootfs
			# Commonly, the generation out-path itself is a /nix/store/<drv> dir. We include it if it matches.
			if is_rootfs_store_dir "$target"; then
				echo -e "${gen}\t${target}"
			else
				# If it contains a file like nixos.img under a store dir, add that store dir
				# This is best-effort; search shallow for nixos.img
				local img
				img="$(find "$target" -maxdepth 2 -type f -name nixos.img 2>/dev/null | head -n1 || true)"
				if [[ -n "$img" ]]; then
					local sd
					sd="$(store_dir_of "$img")"
					if is_rootfs_store_dir "$sd"; then
						echo -e "${gen}\t${sd}"
					fi
				fi
			fi
		done
	fi
}

# Discover candidates from a GC roots directory (sorted by mtime, newest first)
discover_via_gcroots() {
	local roots_dir="$1"
	[[ -d "$roots_dir" ]] || return 0
	# shellcheck disable=SC2012
	ls -1t "$roots_dir" 2>/dev/null | while read -r name; do
		local p="$roots_dir/$name"
		[[ -L "$p" ]] || continue
		local tgt
		tgt="$(resolve_path "$p")"
		# Sometimes GC roots point directly to a file within the store dir (e.g., nixos.img); map to store dir
		local sd
		sd="$(store_dir_of "$tgt")"
		if is_rootfs_store_dir "$sd"; then
			# mtime rank is approximated by ls -t order; we will collapse duplicates later
			echo -e "mtime\t${sd}\t${p}"
		fi
	done
}

# Discover candidates via repo result* symlinks:
# We consider these names ordered: result (gen 0, newest), result-1, result-2, ...
discover_via_results() {
	local dir="$1"
	[[ -d "$dir" ]] || return 0
	shopt -s nullglob
	local arr=()
	# Explicitly prioritize "result" as generation 0 if present
	if [[ -L "$dir/result" ]]; then
		arr+=("$dir/result")
	fi
	# Then numerically sorted result-N (ascending N = older; we will compute order)
	local r
	for r in "$dir"/result-*; do
		[[ -L "$r" ]] || continue
		arr+=("$r")
	done
	shopt -u nullglob

	local i=0
	for r in "${arr[@]}"; do
		local tgt sd
		tgt="$(resolve_path "$r")"
		sd="$(store_dir_of "$tgt")"
		if is_rootfs_store_dir "$sd"; then
			# "i" acts as generation index where 0 is newest
			echo -e "${i}\t${sd}\t${r}"
		fi
		i=$((i + 1))
	done
}

# Discover candidates directly from the Nix store by looking for:
#   /nix/store/*${PATTERN}*/nixos.img
# Results are ordered by nixos.img mtime (newest first).
discover_via_store_glob() {
	local store="/nix/store"
	[[ -d "$store" ]] || return 0

	shopt -s nullglob
	local rows=()
	local img sd mtime
	for img in "$store"/*"$PATTERN"*/nixos.img; do
		[[ -f "$img" ]] || continue
		sd="$(store_dir_of "$img")"
		is_rootfs_store_dir "$sd" || continue
		if command -v stat >/dev/null 2>&1; then
			# Linux: stat -c %Y
			mtime="$(stat -c %Y "$img" 2>/dev/null || true)"
			# BSD/macOS fallback: stat -f %m
			[[ -n "$mtime" ]] || mtime="$(stat -f %m "$img" 2>/dev/null || echo 0)"
		else
			mtime=0
		fi
		rows+=("${mtime}"$'\t'"${sd}"$'\t'"${img}")
	done
	shopt -u nullglob

	if ((${#rows[@]} > 0)); then
		printf '%s\n' "${rows[@]}" | sort -r -n -k1,1
	fi
}

# Collect discovered entries, dedupe, and compute keep/delete sets
# We prefer the first non-empty discovery source in priority order.
declare -a ORDERED
ORDERED=()
declare -A ORIGIN_BY_PATH
declare -A GENIDX_BY_PATH

if [[ -n "$PROFILE" ]]; then
	log_info "Discovering via profile: $PROFILE"
	profile_output=$(discover_via_profile "$PROFILE")
	while IFS=$'\t' read -r gen path; do
		[[ -n "$path" ]] || continue
		if [[ -z "${GENIDX_BY_PATH[$path]:-}" ]]; then
			GENIDX_BY_PATH["$path"]="$gen"
			ORIGIN_BY_PATH["$path"]="profile"
			ORDERED+=("$path")
		fi
	done <<<"$profile_output"
fi

# With set -u, guard for unset arrays using ${ORDERED+x} and ${#ORDERED[@]-0}
if [[ (-z ${ORDERED+x} || ${#ORDERED[@]} -eq 0) && -n "$GCROOTS" ]]; then
	log_info "Discovering via GC roots: $GCROOTS"
	local_rank=0
	gcroots_output=$(discover_via_gcroots "$GCROOTS")
	while IFS=$'\t' read -r key path root; do
		[[ -n "$path" ]] || continue
		if [[ -z "${GENIDX_BY_PATH[$path]:-}" ]]; then
			GENIDX_BY_PATH["$path"]="$local_rank"
			ORIGIN_BY_PATH["$path"]="gcroot:$(basename -- "$root")"
			ORDERED+=("$path")
			local_rank=$((local_rank + 1))
		fi
	done <<<"$gcroots_output"
fi

if [[ -z ${ORDERED+x} || ${#ORDERED[@]} -eq 0 ]]; then
	log_info "Discovering via repo results: $RESULTS_DIR"
	results_output=$(discover_via_results "$RESULTS_DIR")
	while IFS=$'\t' read -r idx path link; do
		[[ -n "$path" ]] || continue
		if [[ -z "${GENIDX_BY_PATH[$path]:-}" ]]; then
			GENIDX_BY_PATH["$path"]="$idx"
			ORIGIN_BY_PATH["$path"]="result:$(basename -- "$link")"
			ORDERED+=("$path")
		fi
	done <<<"$results_output"
fi

# With set -u, guard for unset arrays using ${ORDERED+x} and ${#ORDERED[@]-0}
if [[ -z ${ORDERED+x} || ${#ORDERED[@]} -eq 0 ]]; then
	# Final fallback: scan the Nix store for /nix/store/*${PATTERN}*/nixos.img
	log_info "Discovering via Nix store glob: /nix/store/*${PATTERN}*/nixos.img"
	store_output="$(discover_via_store_glob)"
	local_rank=0
	while IFS=$'\t' read -r mtime path img; do
		[[ -n "$path" ]] || continue
		if [[ -z "${GENIDX_BY_PATH[$path]:-}" ]]; then
			GENIDX_BY_PATH["$path"]="$local_rank"
			ORIGIN_BY_PATH["$path"]="store:$(basename -- "$img")"
			ORDERED+=("$path")
			local_rank=$((local_rank + 1))
		fi
	done <<<"$store_output"
fi

# If still nothing, exit cleanly
if [[ -z ${ORDERED+x} || ${#ORDERED[@]} -eq 0 ]]; then
	log_warn "No rootfs candidates discovered. Nothing to do."
	exit 0
fi

# Sort ORDERED by generation index ascending (0=newest)
# Create an array of "idx\tpath" to sort
TMP_SORT=()
for p in "${ORDERED[@]}"; do
	TMP_SORT+=("${GENIDX_BY_PATH[$p]}"$'\t'"$p")
done
IFS=$'\n' read -r -d '' -a SORTED < <(
	printf '%s\n' "${TMP_SORT[@]}" | sort -n -k1,1
	printf '\0'
)

ORDERED=()
for row in "${SORTED[@]}"; do
	IFS=$'\t' read -r idx path <<<"$row"
	ORDERED+=("$path")
done

log_info "Discovered ${#ORDERED[@]} rootfs candidates:"
for i in "${!ORDERED[@]}"; do
	p="${ORDERED[$i]}"
	log_info "  [$i] keep-order=${GENIDX_BY_PATH[$p]} path=$p origin=${ORIGIN_BY_PATH[$p]}"
done

# Partition into keep and delete
KEEP_N="$KEEP"
if ((KEEP_N > ${#ORDERED[@]})); then
	KEEP_N=${#ORDERED[@]}
fi
KEEP_SET=("${ORDERED[@]:0:KEEP_N}")
DEL_SET=("${ORDERED[@]:KEEP_N}")

if ((${#DEL_SET[@]} == 0)); then
	log_info "Nothing to delete. Already within retention (keep=$KEEP)."
	exit 0
fi

log_info "Plan:"
log_info "  Keep (${#KEEP_SET[@]}):"
for p in "${KEEP_SET[@]}"; do
	log_info "    $p"
done
log_info "  Delete (${#DEL_SET[@]}):"
for p in "${DEL_SET[@]}"; do
	log_info "    $p"
done

# Compute closure sizes for reporting
calc_size_bytes() {
	local p="$1"
	local out num
	if command -v nix >/dev/null 2>&1; then
		# nix path-info --closure-size can output "PATH SIZE" or similar; pick the last numeric field.
		out="$(nix path-info --closure-size "$p" 2>/dev/null | tail -n1 || true)"
		num="$(awk '{
      for (i=NF; i>=1; i--) if ($i ~ /^[0-9]+$/) {print $i; exit}
    }' <<<"$out")"
		echo "${num:-0}"
	elif command -v nix-store >/dev/null 2>&1; then
		# nix-store -q --size often prints "SIZE PATH" or just SIZE; pick the last numeric field.
		out="$(nix-store -q --size "$p" 2>/dev/null | tail -n1 || true)"
		num="$(awk '{
      for (i=NF; i>=1; i--) if ($i ~ /^[0-9]+$/) {print $i; exit}
    }' <<<"$out")"
		echo "${num:-0}"
	else
		echo 0
	fi
}

human_size() {
	local bytes="$1"
	local unit=(B KB MB GB TB)
	local i=0
	local val="$bytes"
	while ((val >= 1024 && i < ${#unit[@]} - 1)); do
		val=$(((val + 512) / 1024))
		i=$((i + 1))
	done
	printf "%d%s" "$val" "${unit[$i]}"
}

TOTAL_BYTES=0
for p in "${DEL_SET[@]}"; do
	sz=$(calc_size_bytes "$p" || echo 0)
	sz=${sz:-0}
	TOTAL_BYTES=$((TOTAL_BYTES + sz))
done

if ((DRY_RUN)); then
	log_info "[DRY-RUN] Would delete ${#DEL_SET[@]} store paths, approx total closure $(human_size "$TOTAL_BYTES")"
else
	log_info "Deleting ${#DEL_SET[@]} store paths, approx total closure $(human_size "$TOTAL_BYTES")"
	for p in "${DEL_SET[@]}"; do
		log_info "Deleting: $p"
		if ! nix-store --delete "$p"; then
			log_warn "Failed to delete $p (may still be referenced); continuing"
		fi
	done
fi

# Optionally remove stale result* symlinks that point to deleted paths
if ((REMOVE_STALE_SYMLINKS)); then
	if [[ -d "$RESULTS_DIR" ]]; then
		shopt -s nullglob
		for r in "$RESULTS_DIR"/result "$RESULTS_DIR"/result-*; do
			[[ -L "$r" ]] || continue
			tgt="$(resolve_path "$r")"
			sd="$(store_dir_of "$tgt")"
			for dp in "${DEL_SET[@]}"; do
				if [[ "$sd" == "$dp" ]]; then
					if ((DRY_RUN)); then
						log_info "[DRY-RUN] Would remove stale symlink: $r"
					else
						log_info "Removing stale symlink: $r"
						rm -f -- "$r" || log_warn "Failed to remove $r"
					fi
					break
				fi
			done
		done
		shopt -u nullglob
	fi
fi

log_success "Cleanup complete."
