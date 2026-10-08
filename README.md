# reolink-doorbell-speaker

Play your own sound through the **Reolink doorbell's built-in speaker** when someone rings, from Home Assistant.
Optionally pick a different sound for holidays and birthdays.

The Home Assistant Reolink integration [says it plainly](https://www.home-assistant.io/integrations/reolink/):
*"2-way audio or Text-to-speech is not available."* The doorbell isn't a `media_player`, and
the only built-in option is a "quick reply". That's a max 10-second message recorded through your
phone's microphone.

The doorbell does, however, accept audio over the **RTSP backchannel**. [go2rtc](https://github.com/AlexxIT/go2rtc)
can use it. This repo is the small amount of glue that makes it work from a doorbell press.

```
ring ──► HA automation ──► rest_command (POST) ──► go2rtc ──► RTSP backchannel ──► doorbell speaker
                                                     │                                (PCMU 8 kHz)
                                                     └─ ffmpeg pulls doorbell_<key>.mp3 from HA's /local
```

## Tested on

- Reolink Video Doorbell **WiFi** (D340W), firmware v3.0.0.6460
- Home Assistant 2026.9
- go2rtc as a standalone binary on a separate Linux box. It doesn't use HA's built-in go2rtc.

Reports of this working have mostly been for the PoE model (D340P). It also works on the WiFi one.

## What's in here

| File | What it does |
|---|---|
| `go2rtc/go2rtc.example.yaml` | go2rtc config: API with basic auth, one stream pointing at the doorbell |
| `go2rtc/go2rtc-doorbell.service` | systemd user service to keep go2rtc running |
| `homeassistant/rest_command.yaml` | The call that tells go2rtc to play a file into the doorbell |
| `homeassistant/automation.yaml` | Ring → sound outside + on Sonos inside, at the same time |
| `homeassistant/doorbell_sound_sensor.yaml` | *Optional.* Picks a sound by date: birthdays (fixed dates or a calendar event), Christmas, New Year, carnival, Easter (computed), Halloween… |
| `tools/make_clip.sh` | Cut a clip from a song: trim, fade, match loudness |

No sound files are included. Bring your own.

## Setup

1. **Enable RTSP on the doorbell.** Reolink app → device settings → *Network information → Advanced* → turn on RTSP. Then **restart the doorbell**, or it won't take effect.
   After a factory reset, all of these services are off again.
2. **Run go2rtc.** Download the binary from the [go2rtc releases](https://github.com/AlexxIT/go2rtc/releases).
   Copy `go2rtc.example.yaml` to `go2rtc.yaml` next to it, fill in the placeholders and run `chmod 600 go2rtc.yaml`.
   Install the systemd service.
3. **Check the backchannel.** Open `http://GO2RTC_HOST:11984`, log in and look at the `doorbell` stream.
   Among its tracks you should see `audio, sendonly, PCMU/8000`. That's the speaker.
4. **Put the sounds in HA.** Save them as `<config>/www/media/doorbell_default.mp3` and so on. They're then served at `http://HA_HOST:8123/local/media/…`.
5. **Add the rest_command** to `configuration.yaml`, plus `go2rtc_api_password` in `secrets.yaml`. **Restart HA.**
6. **Add the automation.** Ring the doorbell.
7. *(Optional)* Add the sound sensor and the extra `doorbell_<key>.mp3` files.

You can test step 5 by hand from *Developer tools → Actions → `rest_command.doorbell_speaker_play`*.

## Gotchas (each one cost me time)

- **`src=` must be a source URL, URL-encoded.** Passing a stream name gives `unsupported scheme`.
- **`rest_command` needs a full restart** the first time you add it. Reloading YAML doesn't load a new integration.
- **Turn off the doorbell's own "ding dong"** (`switch.<doorbell>_doorbell_button_sound`), or it plays on top of your sound. It comes back after a factory reset.
- **go2rtc's `/api/streams` shows the RTSP URL including the doorbell password.** Keep the API behind basic auth and on your LAN only.
- **HA's `/local` sends `Cache-Control: max-age=2678400` (31 days).** If you replace a sound and test it in a browser, you'll hear the old one. Use a new filename for previews. go2rtc/ffmpeg always fetches fresh, so the doorbell itself isn't affected.
- **Don't use HA's built-in go2rtc stream IDs.** They changed in 2026 ([core#170444](https://github.com/home-assistant/core/issues/170444)). A separate go2rtc with your own stream name avoids that.
- If you kill go2rtc by hand, use `pgrep -x go2rtc`. `pkill -f "go2rtc -config"` also matches the shell running the command.

## Limitations

- **Phone quality.** The doorbell takes 8 kHz mono. Speech and melodies work; bass is gone.
- **The doorbell mutes its microphone while playing.** Keep clips short, around 15 seconds or less.
- This plays files. It does not turn the doorbell into a `media_player` for TTS or streaming. That's possible with the
  [WebRTC Camera](https://github.com/AlexxIT/WebRTC) HACS integration against the same go2rtc, but it isn't covered here.

## Credits

All the hard work is [go2rtc](https://github.com/AlexxIT/go2rtc) by AlexxIT. This repo is configuration and notes.

Built with an AI assistant (Claude) doing most of the digging and typing. I tested it at my own front door.

## License

MIT
