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
typedef struct case_manager__PluginInfo__ case_manager__PluginInfo;
typedef c3slice_t String;
struct case_manager__PluginInfo__
{
	c3slice_t name;
	c3slice_t version;
	c3slice_t author;
	c3slice_t description;
};
typedef struct case_manager__PluginAPI__ case_manager__PluginAPI;
typedef void(*case_manager__CommandHandler)(void* client, c3slice_t args);
typedef void(*case_manager__RegisterCommandFn)(c3slice_t, case_manager__CommandHandler, uint64_t, c3slice_t, c3slice_t);
typedef bool(*case_manager__PacketHook)(void* client, void* packet);
typedef void(*case_manager__RegisterHookFn)(c3slice_t, case_manager__PacketHook, c3slice_t);
typedef void*(*case_manager__FindClientFn)(int32_t);
typedef void(*case_manager__BroadcastAreaMsgFn)(int32_t, c3slice_t);
typedef void(*case_manager__BroadcastAreaRawFn)(int32_t, c3slice_t);
typedef void(*case_manager__BroadcastArupFn)(int32_t);
typedef int32_t(*case_manager__GetAreaCountFn)(void);
typedef bool(*case_manager__AreaIsCmFn)(int32_t, int32_t);
typedef void(*case_manager__AreaAddCmFn)(int32_t, int32_t);
typedef void(*case_manager__AreaRemoveCmFn)(int32_t, int32_t);
typedef int32_t(*case_manager__AreaCmCountFn)(int32_t);
typedef void(*case_manager__AreaClearCmsFn)(int32_t);
typedef void(*case_manager__AreaUninviteFn)(int32_t, int32_t);
typedef void(*case_manager__AreaSetStatusFn)(int32_t, int32_t);
typedef int32_t(*case_manager__AreaGetStatusFn)(int32_t);
typedef c3slice_t(*case_manager__AreaGetNameFn)(int32_t);
typedef void(*case_manager__AreaSetSongFn)(int32_t, c3slice_t, int32_t);
typedef void(*case_manager__ForceMoveFn)(void*, int32_t);
typedef void(*case_manager__ClientSendMsgFn)(void*, c3slice_t);
typedef void(*case_manager__ClientSendRawFn)(void*, c3slice_t);
typedef int32_t(*case_manager__ClientGetUidFn)(void*);
typedef int32_t(*case_manager__ClientGetAreaFn)(void*);
typedef bool(*case_manager__ClientIsModFn)(void*);
typedef c3slice_t(*case_manager__ClientDisplayNameFn)(void*);
typedef int32_t(*case_manager__ClientGetCharIdFn)(void*);
typedef c3slice_t(*case_manager__ClientGetShownameFn)(void*);
typedef c3slice_t(*case_manager__ClientGetCharNameFn)(void*);
typedef bool(*case_manager__ClientIsJoinedFn)(void*);
typedef void(*case_manager__ClientSetPositionFn)(void*, c3slice_t);
struct case_manager__PluginAPI__
{
	case_manager__RegisterCommandFn register_command;
	case_manager__RegisterHookFn register_hook;
	case_manager__FindClientFn find_client;
	case_manager__BroadcastAreaMsgFn broadcast_area_msg;
	case_manager__BroadcastAreaRawFn broadcast_area_raw;
	case_manager__BroadcastArupFn broadcast_arup;
	case_manager__GetAreaCountFn get_area_count;
	case_manager__AreaIsCmFn area_is_cm;
	case_manager__AreaAddCmFn area_add_cm;
	case_manager__AreaRemoveCmFn area_remove_cm;
	case_manager__AreaCmCountFn area_cm_count;
	case_manager__AreaClearCmsFn area_clear_cms;
	case_manager__AreaUninviteFn area_uninvite;
	case_manager__AreaSetStatusFn area_set_status;
	case_manager__AreaGetStatusFn area_get_status;
	case_manager__AreaGetNameFn area_get_name;
	case_manager__AreaSetSongFn area_set_song;
	case_manager__ForceMoveFn force_move;
	case_manager__ClientSendMsgFn client_send_msg;
	case_manager__ClientSendRawFn client_send_raw;
	case_manager__ClientGetUidFn client_get_uid;
	case_manager__ClientGetAreaFn client_get_area;
	case_manager__ClientIsModFn client_is_mod;
	case_manager__ClientDisplayNameFn client_display_name;
	case_manager__ClientGetCharIdFn client_get_char_id;
	case_manager__ClientGetShownameFn client_get_showname;
	case_manager__ClientGetCharNameFn client_get_char_name;
	case_manager__ClientIsJoinedFn client_is_joined;
	case_manager__ClientSetPositionFn client_set_position;
};

/* FUNCTIONS */
extern case_manager__PluginInfo whisker_plugin_info(void);
extern bool whisker_plugin_init(case_manager__PluginAPI* plugin_api);
extern void whisker_plugin_shutdown(void);
