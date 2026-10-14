package mobile;

class MobileButton extends FlxSprite
{
	static inline final MARGIN:Float = 16;

	public var key(default, null):String;

	public function new(image:String, prefix:String, key:String, scale:Float = 1)
	{
		super();
		this.key = key;

		frames = Paths.getSparrowAtlas('mobile/$image');
		animation.addByIndices('idle', prefix, [0], '', 24, false);
		animation.addByPrefix('press', prefix, 24, false);
		animation.play('idle');

		this.scale.set(scale, scale);
		updateHitbox();
		scrollFactor.set();
		antialiasing = ClientPrefs.data.antialiasing;

		TouchInput.register(this);
	}

	public static function back(?camera:FlxCamera, top:Bool = false):MobileButton
	{
		var button:MobileButton = new MobileButton('backButton', 'back', 'back', 0.65);
		button.setPosition(FlxG.width - button.width - MARGIN, top ? MARGIN : FlxG.height - button.height - MARGIN);
		if (camera != null) button.cameras = [camera];
		return button;
	}

	public static function pause(?camera:FlxCamera):MobileButton
	{
		var button:MobileButton = new MobileButton('pauseButton', 'pause', 'pause', 0.8);
		button.setPosition(FlxG.width - button.width - MARGIN, MARGIN);
		if (camera != null) button.cameras = [camera];
		return button;
	}

	public function press()
	{
		animation.play('press', true);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (animation.curAnim != null && animation.curAnim.name == 'press' && animation.curAnim.finished)
			animation.play('idle');
	}

	override function destroy()
	{
		TouchInput.unregister(this);
		super.destroy();
	}
}
