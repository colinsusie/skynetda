/**
 * skynet debug adpater
 * by colin
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <signal.h>
#include <sys/wait.h>
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

FILE *logger = NULL;

static void error_exit(const char* format, ...) {
    va_list ap;
    va_start(ap, format);
    vfprintf(logger, format, ap);
    va_end(ap);
    fflush(stdout);
    exit(1);
}

static bool init_debuglog() {
    if (!logger) {
        logger = fopen("debug.log", "w");
        if (logger == NULL)
            return false;
        setbuf(logger, NULL);

        // stderr -> logger
        int fd = fileno(logger);
        if (dup2(fd, STDERR_FILENO) == -1) {
            error_exit("dup2: %s", strerror(errno));
        }
    }
    return true;
}

static void debuglog(const char* format, ...) {
    va_list ap;
    va_start(ap, format);
    vfprintf(logger, format, ap);
    va_end(ap);
}

static int sigign() {
	struct sigaction sa;
	sa.sa_handler = SIG_IGN;
	sa.sa_flags = 0;
	sigemptyset(&sa.sa_mask);
	sigaction(SIGHUP, &sa, 0);
	return 0;
}

static void change_workdir(const char *path) {
    const char *pos = strrchr(path, '/');
    if (pos) {
        int n = pos - path;
        char *wdir = malloc(n+1);
        strncpy(wdir, path, n);
        wdir[n+1] = '\0';
        chdir(wdir);
        free(wdir);
    }
}

static void init_lua_path(lua_State *dL) {
    lua_getglobal(dL, "package");    // [pkg]
    lua_getfield(dL, -1, "path");    // [pkg|path]
    lua_pushstring(dL, "path");      // [pkg|path|pathkey]
    lua_pushfstring(dL, "../?.lua;../?.luac;%s", lua_tostring(dL, -2)); // [pkg|path|pathkey|pathval]
    lua_settable(dL, -4);    // [pkg|path]
    lua_pop(dL, 1); // [pkg]

    lua_getfield(dL, -1, "cpath");    // [pkg|cpath]
    lua_pushstring(dL, "cpath");     // [pkg|cpath|cpathkey]
    lua_pushfstring(dL, "./?.so;%s", lua_tostring(dL, -2)); // [pkg|cpath|cpathkey|cpathval]
    lua_settable(dL, -4);    // [pkg|path]
    lua_pop(dL, 2); // []
}

static bool run_script(lua_State *L) {
    int err = (luaL_loadfile(L, "../debugger.lua") || lua_pcall(L, 0, 6, 0));
    if (err) {
        fprintf(logger, "%s\n", lua_tostring(L, -1));
        return false;
    }
    return true;
}

static void run_skynet(const char *workdir, const char *skynet, const char *config, const char *service,
	bool debug, const char *breakpoints) {
    if (debug)
        setenv("vscdbg_open", "on", 1);
    else
        setenv("vscdbg_open", "off", 1);

    setenv("vscdbg_workdir", workdir, 1);
    setenv("vscdbg_bps", breakpoints, 1);
	setenv("vscdbg_service", service, 1);

	debuglog("workdir: %s\n", workdir);
	debuglog("skynet path: %s\n", skynet);
	debuglog("config path: %s\n", config);
	debuglog("service path: %s\n", service);

    if (chdir(workdir) != 0) {
		error_exit("run_skynet - chdir: %s\n", strerror(errno));
	}

    execl(skynet, skynet, config, NULL);
    error_exit("execl: %s\n", strerror(errno));
}

int main(int argc, char const *argv[]) {
    sigign();
    if (argc > 0)
        change_workdir(argv[0]);
    if (!init_debuglog())
        error_exit("debug log failed");

    lua_State *L = luaL_newstate();
    luaL_openlibs(L);
    init_lua_path(L);
    if (!run_script(L)) {
        error_exit("script error\n");
    }

    const char *workdir = lua_tostring(L, -6);
	const char *skynet = lua_tostring(L, -5);
    const char *config = lua_tostring(L, -4);
	const char *service = lua_tostring(L, -3);
    bool debug = lua_toboolean(L, -2);
    const char *breakpoints = lua_tostring(L, -1);

    int pid = fork();
    if (pid == -1) {
        error_exit("fork: %s\n", strerror(errno));
    } else if (pid != 0) {
        int state;
        if (wait(&state) == -1)
            error_exit("wait: %s\n", strerror(errno));
        debuglog("child exit: %d\n", state);
    } else {
		debuglog("run_skynet\n");
        run_skynet(workdir, skynet, config, service, debug, breakpoints);
    }

    lua_close(L);
    return 0;  
}
