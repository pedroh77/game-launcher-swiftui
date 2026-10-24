#include <stdint.h>
// Read-only symbol loading; never calls the private setter or a hide/show API.
int32_t probe_cursor_symbols(void);
const char *probe_cursor_library(void);
// Affects only this process's WindowServer connection.
int32_t probe_set_background_cursor(int enabled);
