# webAO Rework Protocol Reference

Reference types and parsing from the reworked webAO codebase. Use this as the authoritative source for MS packet field layouts.

Credit: [OmniTroid](https://github.com/omnitroid) for providing the type definitions, parsing code, and field layout clarifications.

Source: https://github.com/AttorneyOnline/webAO

---

## MS Packet Types

The MS packet has two forms depending on direction. The client-bound form has 4 extra server-inserted fields for pairing.

### MSPacketClient (Server -> Client, 30 fields)

The full MS packet as received by the client. Includes all pairing fields inserted by the server.

```typescript
export interface MSPacketClient {
  desk_modifier: DeskModifier;
  preanim: string;
  character: string;
  emote: string;
  message: string;
  side: Side;
  sfx_name: string;
  emote_modifier: EmoteModifier;
  char_id: number;
  sfx_delay: number;
  shout_modifier: ShoutModifier;
  evidence_id: number;
  flip: Flip;
  realization: boolean;
  text_color: TextColor;
  // cccc group
  showname: string;
  paired_charid: number;
  paired_name: string;        // server-inserted
  paired_emote: string;       // server-inserted
  self_offset: Offset;
  paired_offset: Offset;      // server-inserted
  paired_flip: Flip;          // server-inserted
  noninterrupting_preanim: boolean;
  // 2.7 group
  sfx_looping: boolean;
  screenshake: boolean;
  frames_shake: string;
  frames_realization: string;
  frames_sfx: string;
  // 2.8 group
  additive: boolean;
  effect: string;
}
```

### MSPacketServer (Client -> Server, 26 fields)

The MS packet as sent by the client. The 4 server-inserted pairing fields are absent.

```typescript
export type MSPacketServer = Omit<
  MSPacketClient,
  "paired_name" | "paired_emote" | "paired_offset" | "paired_flip"
>;
```

The omitted fields are `paired_name`, `paired_emote`, `paired_offset`, and `paired_flip`. The index shifts accordingly — `self_offset` follows immediately after `paired_charid`, and `noninterrupting_preanim` follows immediately after `self_offset`.

---

## Parsing: Client-Bound (30 fields)

Wire indices are 1-based (field after `MS#` header is `args[1]`).

```typescript
desk_modifier: parseDeskModifier(args[1]),
preanim: str(args[2]),
character: str(args[3]),
emote: str(args[4]),
message: str(args[5]),
side: parseSide(args[6]),
sfx_name: str(args[7]),
emote_modifier: parseEmoteModifier(args[8]),
char_id: intOr(args[9], -1),
sfx_delay: intOr(args[10], 0),
shout_modifier: parseShoutModifier(args[11]),
evidence_id: intOr(args[12], 0),
flip: parseFlip(args[13]),
realization: args[14] === "1",
text_color: parseTextColor(args[15]),
showname: str(args[16]),
paired_charid: intOr(args[17], -1),
paired_name: str(args[18]),           // server-inserted
paired_emote: str(args[19]),          // server-inserted
self_offset: parseOffset(str(args[20])),
paired_offset: parseOffset(str(args[21])),  // server-inserted
paired_flip: parseFlip(args[22]),     // server-inserted
noninterrupting_preanim: args[23] === "1",
sfx_looping: args[24] === "1",
screenshake: args[25] === "1",
frames_shake: str(args[26]),
frames_realization: str(args[27]),
frames_sfx: str(args[28]),
additive: args[29] === "1",
effect: str(args[30]),
```

## Parsing: Server-Bound (26 fields)

Same 1-based wire indices, but the 4 paired_ fields are missing so indices shift after `paired_charid`.

```typescript
desk_modifier: parseDeskModifier(args[1]),
preanim: str(args[2]),
character: str(args[3]),
emote: str(args[4]),
message: str(args[5]),
side: parseSide(args[6]),
sfx_name: str(args[7]),
emote_modifier: parseEmoteModifier(args[8]),
char_id: intOr(args[9], -1),
sfx_delay: intOr(args[10], 0),
shout_modifier: parseShoutModifier(args[11]),
evidence_id: intOr(args[12], 0),
flip: parseFlip(args[13]),
realization: args[14] === "1",
text_color: parseTextColor(args[15]),
showname: str(args[16]),
paired_charid: intOr(args[17], -1),
// Jumps from paired_charid straight to self_offset (no paired_name/emote)
self_offset: parseOffset(str(args[18])),
// Jumps from self_offset straight to noninterrupting_preanim (no paired_offset/flip)
noninterrupting_preanim: args[19] === "1",
sfx_looping: args[20] === "1",
screenshake: args[21] === "1",
frames_shake: str(args[22]),
frames_realization: str(args[23]),
frames_sfx: str(args[24]),
additive: args[25] === "1",
effect: str(args[26]),
```

---

## Field Index Quick Reference

| Field | Client-Bound (0-based) | Server-Bound (0-based) |
|-------|----------------------|----------------------|
| desk_modifier | 0 | 0 |
| preanim | 1 | 1 |
| character | 2 | 2 |
| emote | 3 | 3 |
| message | 4 | 4 |
| side | 5 | 5 |
| sfx_name | 6 | 6 |
| emote_modifier | 7 | 7 |
| char_id | 8 | 8 |
| sfx_delay | 9 | 9 |
| shout_modifier | 10 | 10 |
| evidence_id | 11 | 11 |
| flip | 12 | 12 |
| realization | 13 | 13 |
| text_color | 14 | 14 |
| showname | 15 | 15 |
| paired_charid | 16 | 16 |
| paired_name | 17 | -- |
| paired_emote | 18 | -- |
| self_offset | 19 | 17 |
| paired_offset | 20 | -- |
| paired_flip | 21 | -- |
| noninterrupting_preanim | 22 | 18 |
| sfx_looping | 23 | 19 |
| screenshake | 24 | 20 |
| frames_shake | 25 | 21 |
| frames_realization | 26 | 22 |
| frames_sfx | 27 | 23 |
| additive | 28 | 24 |
| effect | 29 | 25 |
| **Total fields** | **30** | **26** |

---

## Server Responsibility

When relaying an MS packet, the server transforms the 26-field server-bound form into the 30-field client-bound form by:

1. Forwarding fields 0-15 as-is
2. Replacing field 16 (`paired_charid`) with the pair partner's char_id (or -1)
3. Inserting `paired_name` (partner's character folder name)
4. Inserting `paired_emote` (partner's last emote)
5. Forwarding `self_offset` (from server-bound field 17)
6. Inserting `paired_offset` (partner's last offset)
7. Inserting `paired_flip` (partner's last flip state)
8. Forwarding remaining fields (server-bound 18+) shifted by 4

The server also captures `emote` (field 3), `flip` (field 12), and `self_offset` (field 17) from each sender's MS packet so that this data is available when the sender is someone else's pair partner.
