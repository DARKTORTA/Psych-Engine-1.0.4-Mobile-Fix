package mobile;

class TouchButton extends FlxSpriteGroup
{
	public var label(default, null):FlxText;
	public var onPress:Void->Void;
	public var onRelease:Void->Void;
	public var toggled(default, set):Bool = false;

	var bg:FlxSprite;
	var held:Bool = false;
	var releaseQueued:Bool = false;
	var imageMode:Bool = false;
	var idleAlpha:Float = 0.6;
	var pressedAlpha:Float = 0.85;

	public function new(x:Float, y:Float, text:String, width:Int = 160, height:Int = 46, size:Int = 20)
	{
		super(x, y);

		bg = new FlxSprite().makeGraphic(width, height, FlxColor.BLACK);
		bg.alpha = 0.6;
		add(bg);

		label = new FlxText(0, 0, width, text, size);
		label.setFormat(Paths.font("vcr.ttf"), size, FlxColor.WHITE, CENTER);
		label.y = (height - label.height) / 2;
		add(label);

		scrollFactor.set();
		TouchInput.addControl(this);
	}

	public function useImage(graphic:flixel.graphics.FlxGraphic):Bool
	{
		if (graphic == null) return false;
		var width:Int = Std.int(bg.width);
		var height:Int = Std.int(bg.height);
		bg.loadGraphic(graphic);
		bg.setGraphicSize(width, height);
		bg.updateHitbox();
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.setPosition(x, y);
		label.visible = false;
		imageMode = true;
		idleAlpha = 0.8;
		pressedAlpha = 1;
		bg.alpha = idleAlpha;
		set_toggled(toggled);
		return true;
	}

	public var justTapped(get, never):Bool;
	function get_justTapped():Bool
		return TouchInput.controlTapped(this);

	public var isHeld(get, never):Bool;
	function get_isHeld():Bool
		return TouchInput.controlHeld(this);

	function set_toggled(value:Bool):Bool
	{
		toggled = value;
		if (bg != null) bg.color = imageMode ? (value ? 0xFF8FC8FF : FlxColor.WHITE) : (value ? 0xFF3A6EA5 : FlxColor.BLACK);
		return value;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (releaseQueued)
		{
			releaseQueued = false;
			bg.alpha = idleAlpha;
			if (onRelease != null) onRelease();
		}

		var nowHeld:Bool = isHeld;
		if (nowHeld != held)
		{
			held = nowHeld;
			bg.alpha = held ? pressedAlpha : idleAlpha;
			if (held && onPress != null) onPress();
			else if (!held && onRelease != null) onRelease();
		}
		else if (!held && justTapped)
		{
			bg.alpha = pressedAlpha;
			if (onPress != null) onPress();
			releaseQueued = true;
		}
	}

	override function destroy()
	{
		if (held && onRelease != null) onRelease();
		TouchInput.removeControl(this);
		super.destroy();
	}
}
