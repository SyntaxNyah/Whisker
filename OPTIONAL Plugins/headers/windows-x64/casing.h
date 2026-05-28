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
typedef struct casing__PluginInfo__ casing__PluginInfo;
typedef c3slice_t String;
struct casing__PluginInfo__
{
	c3slice_t name;
	c3slice_t version;
	c3slice_t author;
	c3slice_t description;
};
typedef struct casing__PluginAPI__ casing__PluginAPI;
typedef void(*casing__CommandHandler)(void* client, c3slice_t args);
typedef void(*casing__RegisterCommandFn)(c3slice_t, casing__CommandHandler, uint64_t, c3slice_t, c3slice_t);
typedef bool(*casing__PacketHook)(void* client, void* packet);
typedef void(*casing__RegisterHookFn)(c3slice_t, casing__PacketHook, c3slice_t);
typedef void*(*casing__FindClientFn)(int32_t);
typedef void(*casing__BroadcastAreaMsgFn)(int32_t, c3slice_t);
typedef void(*casing__BroadcastAreaRawFn)(int32_t, c3slice_t);
typedef void(*casing__BroadcastArupFn)(int32_t);
typedef int32_t(*casing__GetAreaCountFn)(void);
typedef bool(*casing__AreaIsCmFn)(int32_t, int32_t);
typedef void(*casing__AreaAddCmFn)(int32_t, int32_t);
typedef void(*casing__AreaRemoveCmFn)(int32_t, int32_t);
typedef int32_t(*casing__AreaCmCountFn)(int32_t);
typedef void(*casing__AreaClearCmsFn)(int32_t);
typedef void(*casing__AreaUninviteFn)(int32_t, int32_t);
typedef void(*casing__AreaSetStatusFn)(int32_t, int32_t);
typedef int32_t(*casing__AreaGetStatusFn)(int32_t);
typedef c3slice_t(*casing__AreaGetNameFn)(int32_t);
typedef void(*casing__AreaSetSongFn)(int32_t, c3slice_t, int32_t);
typedef void(*casing__ForceMoveFn)(void*, int32_t);
typedef void(*casing__ClientSendMsgFn)(void*, c3slice_t);
typedef void(*casing__ClientSendRawFn)(void*, c3slice_t);
typedef int32_t(*casing__ClientGetUidFn)(void*);
typedef int32_t(*casing__ClientGetAreaFn)(void*);
typedef bool(*casing__ClientIsModFn)(void*);
typedef c3slice_t(*casing__ClientDisplayNameFn)(void*);
typedef int32_t(*casing__ClientGetCharIdFn)(void*);
typedef c3slice_t(*casing__ClientGetShownameFn)(void*);
typedef c3slice_t(*casing__ClientGetCharNameFn)(void*);
typedef bool(*casing__ClientIsJoinedFn)(void*);
typedef void(*casing__ClientSetPositionFn)(void*, c3slice_t);
typedef void(*casing__BroadcastAllMsgFn)(c3slice_t);
typedef void(*casing__BroadcastAllRawFn)(c3slice_t);
typedef int32_t(*casing__GetPlayerCountFn)(void);
typedef int32_t(*casing__GetAreaPlayerCountFn)(int32_t);
typedef c3slice_t(*casing__ClientGetIpidFn)(void*);
typedef c3slice_t(*casing__PacketGetFieldFn)(void*, int32_t);
typedef int32_t(*casing__PacketGetFieldCountFn)(void*);
typedef void(*casing__ClientKickFn)(void*);
typedef void(*casing__ClientMuteFn)(void*);
typedef void(*casing__ClientUnmuteFn)(void*);
typedef c3slice_t(*casing__AreaGetBackgroundFn)(int32_t);
typedef void(*casing__AreaSetBackgroundFn)(int32_t, c3slice_t);
typedef int32_t(*casing__AreaGetLockFn)(int32_t);
typedef void(*casing__AreaSetLockFn)(int32_t, int32_t);
typedef void(*casing__AreaInviteFn)(int32_t, int32_t);
struct casing__PluginAPI__
{
	casing__RegisterCommandFn register_command;
	casing__RegisterHookFn register_hook;
	casing__FindClientFn find_client;
	casing__BroadcastAreaMsgFn broadcast_area_msg;
	casing__BroadcastAreaRawFn broadcast_area_raw;
	casing__BroadcastArupFn broadcast_arup;
	casing__GetAreaCountFn get_area_count;
	casing__AreaIsCmFn area_is_cm;
	casing__AreaAddCmFn area_add_cm;
	casing__AreaRemoveCmFn area_remove_cm;
	casing__AreaCmCountFn area_cm_count;
	casing__AreaClearCmsFn area_clear_cms;
	casing__AreaUninviteFn area_uninvite;
	casing__AreaSetStatusFn area_set_status;
	casing__AreaGetStatusFn area_get_status;
	casing__AreaGetNameFn area_get_name;
	casing__AreaSetSongFn area_set_song;
	casing__ForceMoveFn force_move;
	casing__ClientSendMsgFn client_send_msg;
	casing__ClientSendRawFn client_send_raw;
	casing__ClientGetUidFn client_get_uid;
	casing__ClientGetAreaFn client_get_area;
	casing__ClientIsModFn client_is_mod;
	casing__ClientDisplayNameFn client_display_name;
	casing__ClientGetCharIdFn client_get_char_id;
	casing__ClientGetShownameFn client_get_showname;
	casing__ClientGetCharNameFn client_get_char_name;
	casing__ClientIsJoinedFn client_is_joined;
	casing__ClientSetPositionFn client_set_position;
	casing__BroadcastAllMsgFn broadcast_all_msg;
	casing__BroadcastAllRawFn broadcast_all_raw;
	casing__GetPlayerCountFn get_player_count;
	casing__GetAreaPlayerCountFn get_area_player_count;
	casing__ClientGetIpidFn client_get_ipid;
	casing__PacketGetFieldFn packet_get_field;
	casing__PacketGetFieldCountFn packet_get_field_count;
	casing__ClientKickFn client_kick;
	casing__ClientMuteFn client_mute;
	casing__ClientUnmuteFn client_unmute;
	casing__AreaGetBackgroundFn area_get_background;
	casing__AreaSetBackgroundFn area_set_background;
	casing__AreaGetLockFn area_get_lock;
	casing__AreaSetLockFn area_set_lock;
	casing__AreaInviteFn area_invite;
};

/* FUNCTIONS */
extern casing__PluginInfo whisker_plugin_info(void);
extern bool whisker_plugin_init(casing__PluginAPI* plugin_api);
extern void whisker_plugin_shutdown(void);
