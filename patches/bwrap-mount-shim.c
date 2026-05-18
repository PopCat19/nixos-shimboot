/* mount_shim.c — intercept mount() to convert tmpfs → bind for ChromeOS LSM
 *
 * Purpose: Transparent LD_PRELOAD shim that converts tmpfs mount calls to
 * bind mounts, bypassing the chromiumos LSM restriction on tmpfs.
 *
 * Usage: LD_PRELOAD=/path/to/mount_shim.so program
 *   or:  bwrap-mount-shim program  (convenience wrapper)
 *
 * Each tmpfs mount gets a unique mkdtemp directory under
 * $BWRAP_CACHE_DIR (default: /tmp/bwrap-cache). Created directories
 * are cleaned up on normal exit via atexit. Best-effort — signal kills
 * or abrupt namespace teardown may leave directories; /tmp is cleared
 * on reboot regardless.
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

/* --- linked list of temp dirs for cleanup --- */
struct dir_entry {
  char *path;
  struct dir_entry *next;
};
static struct dir_entry *dirs = NULL;

static void cleanup_dirs(void) {
  struct dir_entry *d = dirs;
  while (d) {
    rmdir(d->path);
    free(d->path);
    struct dir_entry *prev = d;
    d = d->next;
    free(prev);
  }
  dirs = NULL;
}

static void track_dir(const char *path) {
  struct dir_entry *e = malloc(sizeof(*e));
  if (!e) return;
  e->path = strdup(path);
  e->next = dirs;
  dirs = e;
}

/* --- real mount via dlsym --- */
static int (*real_mount)(const char *, const char *, const char *,
                         unsigned long, const void *) = NULL;

static void init(void) {
  real_mount = dlsym(RTLD_NEXT, "mount");
  if (!real_mount) {
    fprintf(stderr, "mount_shim: dlsym(mount) failed: %s\n", dlerror());
    _exit(1);
  }
  atexit(cleanup_dirs);
}

/* --- mkdtemp wrapper --- */
static int create_bind_target(char **out) {
  const char *cache = getenv("BWRAP_CACHE_DIR");
  if (!cache || !cache[0]) cache = "/tmp/bwrap-cache";

  if (asprintf(out, "%s/tmpfs-XXXXXX", cache) < 0) return -1;

  mkdir(cache, 0700);
  if (!mkdtemp(*out)) {
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

/* --- intercepted mount --- */
int mount(const char *source, const char *target,
          const char *filesystemtype, unsigned long mountflags,
          const void *data) {
  if (!real_mount) init();

  if (filesystemtype && strcmp(filesystemtype, "tmpfs") == 0) {
    char *bind_dir = NULL;
    if (create_bind_target(&bind_dir) != 0) {
      errno = ENOSPC;
      return -1;
    }
    track_dir(bind_dir);
    int ret = real_mount(source, target, NULL, MS_BIND, data);
    free(bind_dir);
    return ret;
  }

  return real_mount(source, target, filesystemtype, mountflags, data);
}
