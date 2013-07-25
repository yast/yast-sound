Audio Agent
===========

Purpose
-------

Audio agent is used for setting the volume for sound cards without need
to call `amixer`, `alsactl`, `mixer` or other external tools.


Dependencies
------------

Package `alsa-devel` > 0.5.1


Interface
=========

*Note: the flags in brackets mean:*

- **d** dir-able, eg. `Dir(.audio.alsa.cards)`
- **r** readable
- **w** writeable
- **x** executable

<pre>
    .audio                          # (d) root
        .alsa                       # (d) access type
            .cards                  # (d) card crossroad
                .0                  # (d)
                    .channels       # (d) channels available for card
                        .PCM        # (drw) volume -- integer [0..100]
                        .mute       # (rw) boolean (true if muted)
                        .Line          ...
                        .volume
                    .name           # (r) description
                    .store          # (x) store values for card #0
                    .restore        # (x) restore values for card #0
                .1
                .2
            .store                  # (x) store values for all cards
            .restore                # (x) restore values for all cards
    .oss                            # (d)
        .cards
                                    .... same as in the alsa section
    .common
</pre>


Tree nodes explanation
----------------------

- `.audio` - non-writable, non-readable node, no special meaning.
  `Dir(.audio)` returns `["alsa", "oss", "common"]`

- `.audio.alsa` - non-writable, non-readable node, no special meaning,
    `Dir(.audio.alsa)` returns `["cards", "restore", "store"]`

- `.audio.alsa.store` - executable, stores volume setting of all cards to `/etc/asound.conf` file

- `.audio.alsa.restore` - executable, loads volume settings from `/etc/asound.conf` to sound cards

- `.audio.alsa.cards` - dir-able, returned value is list of currently *running* cards on alsa sound
  system. Ccards are accessed via `.audio.alsa.cards.<card_number>` path.

- `.audio.alsa.cards.<num>` - has these subpaths:
     - `name` - description of the card
     - `store` - execute to store the volume settings for this card
     - `restore` - execute to restore the settings from disk
	    
- `.audio.alsa.cards.<num>.channels` - dir-able, returns list of accessible channels for the given card,
  eg. `["PCM", "Master"]`

- `.audio.alsa.cards.<num>.chanels.<channel_name>` - dir-able, subpaths are `mute` or `volume`,
  volume is in percent (0-100%), mute is `true` or `false`


Examples
========

Dir
---
 
| Path                                    | Example output           | Description                    |
| --------------------------------------- | ------------------------ | ------------------------------ |
| `Dir(.audio.[alsa/oss].cards)`          | `["0", "1", "2"]`        | Indices of running cards       |
| `Dir(.audio.alsa.cards.1.channels)`     | `["PCM", "Line", "Phone", "Master Mono"]` | List of mixer channels for a given card |
| `Dir(.audio.alsa.cards.1.channels.PCM)` | `["mute", "value"]`      | Properties of the PCM channels |
 

Read
----

| Path                                            | Example output | Description                                   |
| ----------------------------------------------- | -------------- | --------------------------------------------- |
| `Read(.audio.alsa.cards.0.channels.PCM.volume)` | `40`           | Volume in percents for card #0, channel *PCM* |
| `Read(.audio.alsa.cards.0.channels.PCM.mute)`   | `true`         | Channel *PCM* is muted                        |

  


Write
-----

| Path                                                    | Description                                        |
| ------------------------------------------------------- | -------------------------------------------------- |
| `Write(.audio.alsa.cards.1.channels.Phone.volume, 40)`  | Set volume of *Phone* channel to 40% of it's range |
| `Write(.audio.alsa.cards.1.channels.Phone.mute, false)` | Unmute channel *Phone*                             |



Execute
-------

| Path                                   | Description                          |
| -------------------------------------  | ------------------------------------ |
| `Execute(.audio.alsa.store)`           | Store volume settings of all cards   |
| `Execute(.audio.alsa.restore) `        | Restore volume settings of all cards |
| `Execute(.audio.alsa.cards.1.store)`   | Restore volume settings for card 1   |
| `Execute(.audio.alsa.cards.1.restore)` | Restore volume settings for card 1   |

