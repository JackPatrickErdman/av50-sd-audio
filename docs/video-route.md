# The video route: songs as SD-Video clips (untested)

Status: I encoded one file and never played it on the camera. Treat everything below
as an idea with the one experiment that matters still pending. It became moot when the
real SD-Audio route worked (xp-vm-route.md), and then the camera developed a hardware
fault before I got back to it (status.md).

## The idea

The AV50 plays its own video clips from `SD_VIDEO\PRL001\MOLxxx.ASF`. SD-Video on this
camera has no copy protection, and a card with no CPRM area reads fine in the camera.
So a song could be encoded as a "video" with a still cover image, copied to the card,
and played in video mode, on any card, with no SD-Jukebox at all.

## The camera's own format

Two real clips recorded by the camera, probed with ffprobe:

| Stream | Value |
|---|---|
| Container | ASF, comment tag "Panasonic SV-AV50" |
| Video | MPEG-4 part 2, fourcc `MP4S`, 176x144 (the camera's Economy mode) |
| Audio | G.726 ADPCM, 8000 Hz, mono, 32 kbps |

This part is verified: those are the camera's files. ffmpeg reproduces the same stream
layout from any audio file and a cover image:

```
ffmpeg -loop 1 -framerate 6 -i cover.jpg -i song.mp3 -map 0:v -map 1:a -shortest \
  -vf "scale=176:144:force_original_aspect_ratio=decrease,pad=176:144:(ow-iw)/2:(oh-ih)/2,format=yuv420p" \
  -c:v mpeg4 -vtag MP4S -profile:v 0 -level 1 -b:v 64k -g 6 -bf 0 \
  -c:a g726 -ar 8000 -ac 1 -b:a 32k -f asf MOL003.ASF
```

A 4:45 track came out at 4.0 MB, so an album is roughly 40 MB, about 0.85 MB per
minute. ffprobe reports the result with the same stream layout as the camera's clips.
That is all I know.

## Costs, known now

- Telephone-grade audio. G.726 at 8 kHz mono is the only audio codec the camera's
  video decoder has. Nothing above 4 kHz, no stereo. This is a limit of the camera, not
  of the encode.
- No titles. The camera shows clips as 100-0003 and so on.

## Unknowns, to be settled by the test

- Whether the camera needs SD-Video management files alongside the `.ASF`. My card
  dumps did not preserve the non-ASF files in the `SD_VIDEO` tree (one dump's folder
  was unreadable), so I do not know either way.
- Whether a 6 fps still-image stream is accepted, or whether the camera expects one of
  its own frame rates.
- Whether ffmpeg's ASF muxer timing satisfies the camera's demuxer.

## The fallback that cannot be rejected

The Japanese cradle has AV-in. In record mode with [Input select] set to Line, the
camera records composite video and line audio to the card as its own ASF clip. Playing
the album from a PC into that jack produces camera-native files, in real time, at the
same telephone-grade quality. I did not try this either.
