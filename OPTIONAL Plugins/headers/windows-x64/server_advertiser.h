#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#ifndef __c3__
#define __c3__

typedef void* c3typeid_t;
typedef void* c3fault_t;
typedef struct { void* ptr; size_t len; } c3slice_t;
typedef struct { void* ptr; c3typeid_t type; } c3any_t;

#endif

/* TYPES */
typedef struct server_advertiser__PluginInfo__ server_advertiser__PluginInfo;
typedef c3slice_t String;
struct server_advertiser__PluginInfo__
{
	c3slice_t name;
	c3slice_t version;
	c3slice_t author;
	c3slice_t description;
};
typedef struct server_advertiser__PluginAPI__ server_advertiser__PluginAPI;
struct server_advertiser__PluginAPI__
{
	void* manager;
};

/* FUNCTIONS */
extern server_advertiser__PluginInfo whisker_plugin_info(void);
extern bool whisker_plugin_init(server_advertiser__PluginAPI* api);
extern void whisker_plugin_shutdown(void);
