# HTTP API reference

The web radio exposes custom Tasmota commands (defined in
`filesystem/main_prog.be`). They can be called from the Tasmota console, over
HTTP, or via MQTT — useful for home-automation integrations, physical buttons,
or scripts.

## Calling a command over HTTP

```
http://<device>/cm?cmnd=<Command>%20<payload>
```

Example (play favorite 2):

```
http://webradio1.local/cm?cmnd=PlayFav%202
```

If a web/admin password is set, add `&user=admin&password=<yourpassword>`.

---

## Commands

| Command | Payload | Description |
|---------|---------|-------------|
| `Play` | — | Play the last station (resumes the last played stream). |
| `PlayLast` | — | Same as `Play`: replays the last saved station. |
| `PlayFav` | favorite number (1-based) | Play a saved favorite, e.g. `PlayFav 3`. |
| `PlayUrl` | `name\|\|u=url` or just `url` | Play an arbitrary stream. With `name||u=url` the name is stored; with a bare URL the name defaults to "web". |
| `Stop` | — | Stop playback. |
| `Vol` | 0–100 | Set volume (mapped to the DAC gain). Values outside 0–100 are rejected. |
| `SaveFav` | `num=N\|\|name=...\|\|url=...` | Save a favorite in slot N (1-based), e.g. `SaveFav num=2||name=FIP||url=http://...`. |
| `GetFav` | — | Return the favorites list as JSON: `[{"num":1,"name":"...","url":"..."}, ...]`. |
| `SetPlaylist` | `url=...\|\|url=...\|\|mode=...\|\|index=...` | Load a playlist. Repeat `url=` for each track; optional `mode=` and `index=`. Starts playing `index`. |
| `SetPlayMode` | `one` \| `loop_one` \| `all` \| `loop_all` \| `shuffle` | Set the playlist play mode. |
| `GetPlayMode` | — | Return the current play mode as a string. |

---

## Playlist modes

| Mode | Behaviour at end of track |
|------|---------------------------|
| `one` | Stop (single track, no advance). |
| `loop_one` | Repeat the same track. |
| `all` | Advance to the next track, stop after the last. |
| `loop_all` | Advance to the next track, wrap around to the first. |
| `shuffle` | Jump to a random track. |

---

## Notes

- Favorites and the last station are persisted on the device
  (`_persist.json`), so they survive a reboot.
- Track transitions for playlists are driven by the
  `Event#I2SPlay=Ended` rule.
- The now-playing title is refreshed periodically (`Status 8`) and exposed
  through the standard Tasmota sensor data.
