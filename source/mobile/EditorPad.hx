package mobile;

import flixel.input.keyboard.FlxKey;
import openfl.events.KeyboardEvent;

class EditorPad extends FlxSpriteGroup
{
	static inline final KEY_WIDTH:Int = 80;
	static inline final KEY_HEIGHT:Int = 48;
	static inline final GAP:Int = 6;
	static inline final MARGIN:Int = 8;

	static final STICKY:Array<FlxKey> = [SHIFT, CONTROL, ALT];
	static final DPAD_KEYS:Array<String> = ['LEFT', 'DOWN', 'UP', 'RIGHT'];
	static final ACTION_KEYS:Array<String> = ['ESCAPE', 'ENTER', 'SPACE'];
	static final LABELS:Map<String, String> = [
		'ESCAPE' => 'ESC',
		'CONTROL' => 'CTRL',
		'BACKSPACE' => 'BKSP',
		'DELETE' => 'DEL',
		'LEFT' => '<',
		'RIGHT' => '>',
		'UP' => '^',
		'DOWN' => 'v',
		'LBRACKET' => '[',
		'RBRACKET' => ']'
	];

	public static var current(default, null):EditorPad;

	var padCamera:FlxCamera;
	var virtualPad:VirtualPad;
	var toggleButton:TouchButton;
	var keyButtons:Array<TouchButton> = [];
	var keyCodes:Array<FlxKey> = [];
	var heldKeys:Array<FlxKey> = [];
	var shown:Bool = false;
	var escapeQueued:Bool = false;

	public function new(rows:Array<String>)
	{
		super();

		padCamera = new FlxCamera();
		padCamera.bgColor.alpha = 0;
		FlxG.cameras.add(padCamera, false);

		var names:Array<String> = [for (row in rows) for (name in row.split(' ')) name];
		var hasDpad:Bool = false;
		for (name in DPAD_KEYS) if (names.contains(name)) hasDpad = true;
		var actions:Array<FlxKey> = [for (name in ACTION_KEYS) if (names.contains(name)) FlxKey.fromString(name)];

		virtualPad = new VirtualPad(hasDpad, actions);
		virtualPad.onKey = setKey;
		add(virtualPad);

		var keyRows:Array<Array<String>> = [];
		for (row in rows)
		{
			var keys:Array<String> = [for (name in row.split(' ')) if (name.length > 0 && !(hasDpad && DPAD_KEYS.contains(name)) && !ACTION_KEYS.contains(name)) name];
			if (keys.length > 0) keyRows.push(keys);
		}

		var toggleWidth:Int = KEY_WIDTH + 10;
		toggleButton = new TouchButton((FlxG.width - toggleWidth) / 2, FlxG.height - KEY_HEIGHT - MARGIN, 'KEYS', toggleWidth, KEY_HEIGHT, 18);
		toggleButton.useImage(keyImage('keys'));
		toggleButton.visible = keyRows.length > 0;
		add(toggleButton);

		for (rowIndex in 0...keyRows.length)
		{
			var keys:Array<String> = keyRows[rowIndex];
			var rowWidth:Float = keys.length * KEY_WIDTH + (keys.length - 1) * GAP;
			var startX:Float = (FlxG.width - rowWidth) / 2;
			var y:Float = FlxG.height - MARGIN - (KEY_HEIGHT + GAP) * (keyRows.length - rowIndex + 1);
			for (column in 0...keys.length)
			{
				var key:FlxKey = FlxKey.fromString(keys[column]);
				if (key == NONE) continue;

				var label:String = LABELS.exists(keys[column]) ? LABELS.get(keys[column]) : keys[column];
				var button:TouchButton = new TouchButton(startX + column * (KEY_WIDTH + GAP), y, label, KEY_WIDTH, KEY_HEIGHT, 18);
				button.useImage(keyImage(keys[column]));
				button.visible = false;
				if (!STICKY.contains(key))
				{
					button.onPress = function() setKey(key, true);
					button.onRelease = function() setKey(key, false);
				}
				keyButtons.push(button);
				keyCodes.push(key);
				add(button);
			}
		}

		cameras = [padCamera];
		TouchInput.blockGestures = true;
		current = this;
	}

	static function keyImage(name:String):flixel.graphics.FlxGraphic
	{
		return Paths.image('mobile/virtualpad/keys/' + name.toLowerCase());
	}

	public function setSuspended(suspended:Bool)
	{
		toggleButton.visible = !suspended && keyButtons.length > 0;
		virtualPad.visible = !suspended;
		virtualPad.releaseAll();
		for (button in keyButtons) button.visible = shown && !suspended;
		for (key in heldKeys.copy()) setKey(key, false);
		for (i in 0...keyButtons.length)
			if (STICKY.contains(keyCodes[i])) keyButtons[i].toggled = false;
		TouchInput.blockGestures = !suspended;
	}

	override function update(elapsed:Float)
	{
		if (escapeQueued)
		{
			escapeQueued = false;
			setKey(ESCAPE, false);
		}

		super.update(elapsed);

		if (toggleButton.visible && toggleButton.justTapped)
		{
			shown = !shown;
			for (button in keyButtons) button.visible = shown;
			toggleButton.toggled = shown;
		}

		for (i in 0...keyButtons.length)
		{
			var key:FlxKey = keyCodes[i];
			if (STICKY.contains(key) && keyButtons[i].justTapped)
			{
				keyButtons[i].toggled = !keyButtons[i].toggled;
				setKey(key, keyButtons[i].toggled);
			}
		}

		#if android
		if (FlxG.android.justReleased.BACK)
		{
			setKey(ESCAPE, true);
			escapeQueued = true;
		}
		#end
	}

	function setKey(key:FlxKey, down:Bool)
	{
		if (down == heldKeys.contains(key)) return;
		if (down) heldKeys.push(key);
		else heldKeys.remove(key);
		FlxG.stage.dispatchEvent(new KeyboardEvent(down ? KeyboardEvent.KEY_DOWN : KeyboardEvent.KEY_UP, true, false, 0, key));
	}

	override function destroy()
	{
		if (current == this) current = null;
		TouchInput.blockGestures = false;
		for (key in heldKeys.copy()) setKey(key, false);
		if (padCamera != null && FlxG.cameras.list.contains(padCamera))
			FlxG.cameras.remove(padCamera);
		padCamera = null;
		super.destroy();
	}
}
