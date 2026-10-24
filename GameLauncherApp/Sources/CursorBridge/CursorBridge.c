#include "CursorBridge.h"
#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>

// Deliberately private, dynamically resolved ABI. Availability is NOT proof that
// SetsCursorInBackground still works on a particular macOS release.
typedef int32_t (*ConnectionFunction)(void);
typedef int32_t (*PropertyFunction)(int32_t, int32_t, CFStringRef, CFTypeRef);
static ConnectionFunction connection_function;
static PropertyFunction property_function;
static const char *loaded_library = "unavailable";
static int32_t owned_connection;
static int attempted;

int32_t probe_cursor_symbols(void) {
    if (attempted) return connection_function && property_function;
    attempted = 1;
    const char *paths[] = {
        "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
        "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices"
    };
    for (unsigned i = 0; i < sizeof(paths) / sizeof(paths[0]); ++i) {
        void *handle = dlopen(paths[i], RTLD_LAZY | RTLD_LOCAL);
        if (!handle) continue;
        ConnectionFunction connection = (ConnectionFunction)dlsym(handle, "_CGSDefaultConnection");
        if (!connection) connection = (ConnectionFunction)dlsym(handle, "CGSMainConnectionID");
        PropertyFunction property = (PropertyFunction)dlsym(handle, "CGSSetConnectionProperty");
        if (connection && property) {
            connection_function = connection;
            property_function = property;
            loaded_library = paths[i];
            // Retain the handle for the process lifetime, including final cleanup.
            return 1;
        }
        dlclose(handle);
    }
    return 0;
}
const char *probe_cursor_library(void) { return loaded_library; }
int32_t probe_set_background_cursor(int enabled) {
    if (!probe_cursor_symbols()) return -10000;
    if (enabled) owned_connection = connection_function();
    if (!owned_connection) return -10001;
    return property_function(owned_connection, owned_connection,
                             CFSTR("SetsCursorInBackground"),
                             enabled ? kCFBooleanTrue : kCFBooleanFalse);
}
