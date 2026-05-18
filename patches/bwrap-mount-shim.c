/* mount_shim.c — intercept mount() to convert tmpfs → bind for ChromeOS LSM
 *
 * Purpose: Transparent LD_PRELOAD shim that converts tmpfs mount calls to
 * bind mounts, bypassing the chromiumos LSM restriction on tmpfs.
 *
 * Usage: LD_PRELOAD=/path/to/mount_shim.so program
 *   or:  bwrap-mount-shim program  (wrapper script)
 *
 * Each tmpfs mount gets a unique mkdtemp directory under
 * $BWRAP_CACHE_DIR (default: /tmp/bwrap-cache).
 * Directories are NOT cleaned up automatically — they live in /tmp
 * and vanish on reboot. No atexit hook because we don't control the
 * process lifecycle (the host bwrap may kill the namespace abruptly).
 */

#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <unistd.h>

static int (*real_mount)(const char *, const char *, const char *,
                         unsigned long, const void *) = NULL;

static void init(void) {
  real_mount = dlsym(RTLD_NEXT, "mount");
  if (!real_mount) {
    fprintf(stderr, "mount_shim: dlsym(mount) failed: %s\n", dlerror());
    _exit(1);
  }
}

static int create_bind_target(const char *constraint, char **out) {
  const char *cache = getenv("BWRAP_CACHE_DIR");
  if (!cache || !cache[0]) cache = "/tmp/bwrap-cache";

  if (asprintf(out, "%s/tmpfs-XXXXXX", cache) < 0) return -1;

  mkdir(cache, 0700);
  if (!mkdtemp(*out)) {
    /* mkdtemp fails if cache dir doesn't exist — try /tmp */
    free(*out);
    if (asprintf(out, "/tmp/bwrap-cache/tmpfs-XXXXXX") < 0) return -1;
    mkdir("/tmp/bwrap-cache", 0700);
    if (!mkdtemp(*out)) {
      free(*out);
      return -1;
    }
  }
  chmod(*out, 0700);
  return 0;
}

int mount(const char *source, const char *target,
          const char *filesystemtype, unsigned long mountflags,
          const void *data) {
  if (!real_mount) init();

  if (filesystemtype && strcmp(filesystemtype, "tmpfs") == 0) {
    char *bind_dir = NULL;
    if (create_bind_target(target, &bind_dir) != 0) {
      errno = ENOSPC;
      return -1;
    }
    int ret = real_mount(source, target, NULL, MS_BIND, data);
    free(bind_dir);
    return ret;
  }

  return real_mount(source, target, filesystemtype, mountflags, data);
}
