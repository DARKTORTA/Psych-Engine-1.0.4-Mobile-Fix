package mobile;

class ImageButton extends FlxSprite
{
	var baseScale:Float;

	public function new(x:Float, y:Float, image:String, scale:Float = 1)
	{
		super(x, y);
		loadGraphic(Paths.image('mobile/$image'));
		baseScale = scale;
		this.scale.set(scale, scale);
		updateHitbox();
		scrollFactor.set();
		antialiasing = ClientPrefs.data.antialiasing;
		TouchInput.addControl(this);
	}

	public var justTapped(get, never):Bool;
	function get_justTapped():Bool
		return TouchInput.controlTapped(this);

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		var target:Float = TouchInput.controlHeld(this) ? baseScale * 0.92 : baseScale;
		var current:Float = scale.x + (target - scale.x) * Math.min(1, elapsed * 20);
		scale.set(current, current);
		alpha = TouchInput.controlHeld(this) ? 0.85 : 1;
	}

	override function destroy()
	{
		TouchInput.removeControl(this);
		super.destroy();
	}
}
