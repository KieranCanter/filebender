#ifndef FILEBENDER_H
#define FILEBENDER_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    FB_OK = 0,
    FB_ERR_OUT_OF_MEMORY,
    FB_ERR_IO,
    FB_ERR_PERMISSION,
    FB_ERR_NOT_FOUND,
    FB_ERR_NOT_A_DIRECTORY,
    FB_ERR_RING_SETUP,
    FB_ERR_INOTIFY_LIMIT,
    FB_ERR_CANCELLED,
    FB_ERR_DISK_FULL,
    FB_ERR_NAME_CONFLICT,
} fb_error_code;

#ifdef __cplusplus
}
#endif

#endif
