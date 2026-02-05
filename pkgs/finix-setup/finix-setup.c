/*
 * finix-setup - finit plugin for finix early boot initialization
 *
 * this plugin handles:
 * - setting initial PATH (baked in at build time)
 * - deriving systemConfig from argv[0]
 * - creating /run/booted-system and initial /run/current-system symlinks
 * - running the activation script
 */

#include <errno.h>
#include <fcntl.h>
#include <libgen.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/wait.h>

#include <finit/finit.h>
#include <finit/plugin.h>
#include <finit/log.h>

/*
 * finit requires fsck, modprobe & mount commands before PATH can be read from finit.conf
 * substituted by nix at build time
 */
static const char *INITIAL_PATH = "@initialPath@";

static char *system_config = NULL;

/*
 * determine the system configuration path (toplevel) from argv[0].
 *
 * when the kernel boots with init=/nix/store/xxx-finix-system/init,
 * argv[0] preserves that path (even though init is a symlink to finit).
 * the systemConfig is the parent directory of argv[0].
 */
static char *get_system_config(void)
{
    char cmdline[PATH_MAX];
    char *copy;
    int fd;
    ssize_t n;

    if (system_config)
        return system_config;

    fd = open("/proc/self/cmdline", O_RDONLY);
    if (fd < 0) {
        logit(LOG_ERR, "finix-setup: failed to open /proc/self/cmdline");
        return NULL;
    }

    n = read(fd, cmdline, sizeof(cmdline) - 1);
    close(fd);

    if (n <= 0) {
        logit(LOG_ERR, "finix-setup: failed to read /proc/self/cmdline");
        return NULL;
    }
    cmdline[n] = '\0';

    /*
     * cmdline contains null-separated arguments.
     * argv[0] is the first null-terminated string.
     * we need to copy it before calling dirname() since dirname may modify its argument.
     */
    copy = strdup(cmdline);
    if (!copy) {
        logit(LOG_ERR, "finix-setup: strdup failed");
        return NULL;
    }

    system_config = strdup(dirname(copy));
    free(copy);

    if (system_config)
        logit(LOG_INFO, "finix-setup: systemConfig = %s", system_config);
    else
        logit(LOG_ERR, "finix-setup: failed to determine systemConfig");

    return system_config;
}

/*
 * run a command and wait for completion.
 * returns 0 on success, -1 on fork/wait failure, or the exit status.
 */
static int run_cmd(const char *cmd, const char *desc)
{
    pid_t pid;
    int status;

    logit(LOG_INFO, "finix-setup: running %s: %s", desc, cmd);

    pid = fork();
    if (pid < 0) {
        logit(LOG_ERR, "finix-setup: fork failed for %s: %s", desc, strerror(errno));
        return -1;
    }

    if (pid == 0) {
        execl(cmd, cmd, NULL);
        logit(LOG_ERR, "finix-setup: execl failed for %s: %s", desc, strerror(errno));
        _exit(127);
    }

    if (waitpid(pid, &status, 0) < 0) {
        logit(LOG_ERR, "finix-setup: waitpid failed for %s: %s", desc, strerror(errno));
        return -1;
    }

    if (WIFEXITED(status)) {
        int rc = WEXITSTATUS(status);
        if (rc != 0)
            logit(LOG_ERR, "finix-setup: %s exited with status %d", desc, rc);
        else
            logit(LOG_INFO, "finix-setup: %s completed successfully", desc);
        return rc;
    }

    if (WIFSIGNALED(status)) {
        logit(LOG_ERR, "finix-setup: %s killed by signal %d", desc, WTERMSIG(status));
        return -1;
    }

    return -1;
}

/*
 * create /run symlinks.
 * this runs at HOOK_BASEFS_UP, after /run is mounted.
 * activation already ran in PLUGIN_INIT.
 */
static void create_run_symlinks(void *arg)
{
    char *sys;

    (void)arg;

    sys = get_system_config();
    if (!sys) {
        logit(LOG_ERR, "finix-setup: cannot create symlinks without systemConfig");
        return;
    }

    /* create symlinks in /run (now that it's mounted) */
    logit(LOG_INFO, "finix-setup: creating /run/booted-system symlink");
    if (symlink(sys, "/run/booted-system") < 0 && errno != EEXIST)
        logit(LOG_ERR, "finix-setup: failed to create /run/booted-system: %s", strerror(errno));

    logit(LOG_INFO, "finix-setup: creating /run/current-system symlink");
    if (symlink(sys, "/run/current-system") < 0 && errno != EEXIST)
        logit(LOG_ERR, "finix-setup: failed to create /run/current-system: %s", strerror(errno));
}

static plugin_t plugin = {
    .name = "finix-setup",
    .hook[HOOK_BASEFS_UP] = { .cb = create_run_symlinks },
};

PLUGIN_INIT(finix_setup_init)
{
    char *sys;
    char activate_path[PATH_MAX];

    logit(LOG_NOTICE, "\n[1;32m<<< finix - stage 2 >>>[0m\n");

    logit(LOG_INFO, "finix-setup: setting PATH");
    setenv("PATH", INITIAL_PATH, 1);

    /*
     * run activation script in PLUGIN_INIT, BEFORE finit reads its config.
     * this ensures /etc/finit.conf exists when finit parses configuration.
     *
     * NOTE: /run is not mounted yet, so we create the symlinks later in HOOK_BASEFS_UP.
     */
    sys = get_system_config();
    if (!sys) {
        logit(LOG_ERR, "finix-setup: cannot activate without systemConfig");
        plugin_register(&plugin);
        return;
    }

    snprintf(activate_path, sizeof(activate_path), "%s/activate", sys);
    run_cmd(activate_path, "activation script");

    plugin_register(&plugin);
}

PLUGIN_EXIT(finix_setup_exit)
{
    plugin_unregister(&plugin);
    free(system_config);
    system_config = NULL;
}
