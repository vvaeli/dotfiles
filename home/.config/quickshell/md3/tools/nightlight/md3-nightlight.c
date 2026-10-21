// Night light for Hyprland through hyprland-ctm-control-v1: the colour matrix is applied by the
// compositor after everything is drawn, so screenshots stay untinted and Hyprland fades changes.
// Reads "r g b" multipliers from stdin, one line per change; on EOF the filter is released.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <poll.h>
#include <unistd.h>
#include <wayland-client.h>
#include "ctm-protocol.h"

#define MAX_OUTPUTS 16
static struct wl_output *outputs[MAX_OUTPUTS];
static int output_count;
static struct hyprland_ctm_control_manager_v1 *manager;
static double cr = 1, cg = 1, cb = 1;

static void blocked(void *data, struct hyprland_ctm_control_manager_v1 *m) {
    fprintf(stderr, "blocked: another CTM client is active\n");
    exit(2);
}
static const struct hyprland_ctm_control_manager_v1_listener manager_listener = { .blocked = blocked };

static void global(void *data, struct wl_registry *registry, uint32_t name, const char *interface, uint32_t version) {
    if (!strcmp(interface, wl_output_interface.name) && output_count < MAX_OUTPUTS)
        outputs[output_count++] = wl_registry_bind(registry, name, &wl_output_interface, 1);
    else if (!strcmp(interface, hyprland_ctm_control_manager_v1_interface.name)) {
        manager = wl_registry_bind(registry, name, &hyprland_ctm_control_manager_v1_interface, version < 2 ? version : 2);
        hyprland_ctm_control_manager_v1_add_listener(manager, &manager_listener, NULL);
    }
}
static void global_remove(void *data, struct wl_registry *registry, uint32_t name) {}
static const struct wl_registry_listener registry_listener = { global, global_remove };

static void apply(void) {
    for (int i = 0; i < output_count; ++i)
        hyprland_ctm_control_manager_v1_set_ctm_for_output(manager, outputs[i],
            wl_fixed_from_double(cr), 0, 0, 0, wl_fixed_from_double(cg), 0, 0, 0, wl_fixed_from_double(cb));
    hyprland_ctm_control_manager_v1_commit(manager);
}

int main(void) {
    struct wl_display *display = wl_display_connect(NULL);
    if (!display) { fprintf(stderr, "no wayland display\n"); return 1; }
    struct wl_registry *registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &registry_listener, NULL);
    wl_display_roundtrip(display);
    if (!manager) { fprintf(stderr, "compositor lacks hyprland_ctm_control_manager_v1\n"); return 1; }
    char buffer[512];
    size_t used = 0;
    struct pollfd fds[2] = { { wl_display_get_fd(display), POLLIN, 0 }, { 0, POLLIN, 0 } };
    for (;;) {
        wl_display_flush(display);
        if (poll(fds, 2, -1) < 0) break;
        if (fds[0].revents & POLLIN && wl_display_dispatch(display) < 0) break;
        if (fds[0].revents & (POLLERR | POLLHUP)) break;
        if (fds[1].revents & (POLLIN | POLLHUP)) {
            ssize_t n = read(0, buffer + used, sizeof buffer - 1 - used);
            if (n <= 0) break;
            used += n;
            buffer[used] = 0;
            // Only the newest complete line matters.
            char *end = strrchr(buffer, '\n');
            if (!end) { if (used >= sizeof buffer - 1) used = 0; continue; }
            *end = 0;
            char *start = strrchr(buffer, '\n');
            double r, g, b;
            if (sscanf(start ? start + 1 : buffer, "%lf %lf %lf", &r, &g, &b) == 3) { cr = r; cg = g; cb = b; apply(); }
            used = strlen(end + 1);
            memmove(buffer, end + 1, used);
        }
    }
    hyprland_ctm_control_manager_v1_destroy(manager);
    wl_display_flush(display);
    wl_display_disconnect(display);
    return 0;
}
