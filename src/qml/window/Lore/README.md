LoreView now supports two display modes controlled via JSON:

- circle: Dynamic circle background with centered content (default)
- scene: Visual-novel style with background CG, character sprites, and a bottom text box

Where to set mode

You can set a default mode for the whole chapter in `meta.mode`, override per-node via `node.mode`, and override per-content via `content.mode`.

```json
{
	"meta": {
		"chapterId": "prologue",
		"title": "序章",
		"startNode": "start",
		"mode": "scene"
	},
	"nodes": {
		"start": {
			"mode": "circle",
			"contents": [ { "type": "text", "text": "好黑..." } ],
			"nextNode": "awake"
		}
	}
}
```

Per-content override

Each item inside `contents` can set `mode` to override the node/chapter mode. This is useful when a single node mixes different presentation styles line by line.

```json
{
	"nodes": {
		"mix": {
			"mode": "scene",
			"background": "qrc:/resource/image/bg/room.png",
			"characters": [ { "image": "qrc:/resource/image/char/hero.png", "position": "left" } ],
			"contents": [
				{ "type": "text", "text": "这句在场景文字框里显示", "mode": "scene" },
				{ "type": "text", "text": "这句切回动态圆显示", "mode": "circle" }
			]
		}
	}
}
```

Mode resolution precedence: `content.mode` > `node.mode` > `meta.mode` > `"circle"`.

Note: VisualScene currently renders `type: "text"` contents in the bottom text box; other content types will fall back to the default `ContentLoader` rendering.

Per-content music control

Each `content` item can optionally control the global BGM by adding one of:

- `music`: string - a qrc or file path to play (calls `window.playMusic(source, loops)`)
- `musicLoops`: number or `MediaPlayer` loops value (optional)
- `stopMusic`: boolean - if true, calls `window.stopMusic()` to stop playback

Example:

```json
{
	"type": "text",
	"text": "紧张的气氛涌上心头。",
	"mode": "scene",
	"music": "qrc:/resource/audio/gameViewBgm/fight.mp3",
	"musicLoops": -1
}

{
	"type": "text",
	"text": "静默片刻。",
	"mode": "scene",
	"stopMusic": true
}
```

Only include the `music`/`stopMusic` fields on the sentences that need to change the BGM; other sentences will leave playback unchanged.

Speaker name and dialogue layout

When using `scene` mode you can attach speaker metadata to a `content` item so the UI shows the speaker's name above the textbox and centers the dialogue text:

- `speakerName`: string — explicit name to show above the text box.
- `speaker`: integer — index into `node.characters` to use that character's metadata (e.g. name or position).
- `speakerPos`: string — optional override for the badge position: `"left"`, `"center"`, or `"right"`.

Behavior:
- The bottom text box now centers its text horizontally.
- If `speakerName` or `speaker` is provided, a name badge appears just above the text box. The badge aligns left/center/right according to `speakerPos`, or the referenced character's `position`.

Example:

```json
{
	"type": "text",
	"text": "你醒来，发现自己身处陌生的房间。",
	"mode": "scene",
	"speaker": 0
}
```

Or explicitly:

```json
{
	"type": "text",
	"text": "这是另一个人的台词。",
	"mode": "scene",
	"speakerName": "莉娜",
	"speakerPos": "right"
}
```

Precise alignment to character images

If you want the name badge to align more precisely with a character's portrait, use `"speaker": <index>` (index refers to `node.characters`). VisualScene will read the mounted image's position after it instantiates the character images and align the badge's X coordinate to the character's center. This makes the badge appear closely attached to the character's portrait.

Example:

```json
{
	"type": "text",
	"text": "你醒来，发现自己身处陌生的房间。",
	"mode": "scene",
	"speaker": 0
}
```

Notes:
- Alignment depends on the character Image instance being created; VisualScene attempts to adjust the badge position after character images load. If you need edge alignment (left/right) or offsets, I can add `speakerAlign` and `speakerOffset` fields to control that.

