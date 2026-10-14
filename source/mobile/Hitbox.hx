package mobile;

import flixel.util.FlxGradient;
import openfl.display.BitmapData;
import openfl.geom.Rectangle;

class Hitbox extends FlxSpriteGroup
{
	static final COLORS:Array<FlxColor> = [0xFFC24B99, 0xFF00FFFF, 0xFF12FA05, 0xFFF9393F];
	static inline final EDGE:Int = 4;
	static inline final PRESSED_ALPHA:Float = 0.75;
	static inline final FADE_OUT_SPEED:Float = 8;

	var lanes:Array<FlxSprite> = [];

	public function new()
	{
		super();

		var laneWidth:Int = Std.int(FlxG.width / TouchInput.LANES);
		var laneGraphic:BitmapData = createLaneBitmap(laneWidth, FlxG.height);
		for (i in 0...TouchInput.LANES)
		{
			var lane:FlxSprite = new FlxSprite(i * laneWidth, 0);
			lane.loadGraphic(laneGraphic.clone());
			lane.color = COLORS[i % COLORS.length];
			lane.alpha = 0;
			lane.antialiasing = ClientPrefs.data.antialiasing;
			lanes.push(lane);
			add(lane);
		}
		laneGraphic.dispose();

		scrollFactor.set();
		visible = ClientPrefs.data.hitboxVisible;
		TouchInput.hitboxEnabled = true;
	}

	static function createLaneBitmap(width:Int, height:Int):BitmapData
	{
		var bitmap:BitmapData = FlxGradient.createGradientBitmapData(width, height, [0xB0FFFFFF, 0x10FFFFFF, 0x10FFFFFF, 0xB0FFFFFF], 1, 0);
		var glow:BitmapData = FlxGradient.createGradientBitmapData(width, Std.int(height * 0.35), [0x00FFFFFF, 0x60FFFFFF], 1, 90);
		bitmap.copyPixels(glow, glow.rect, new openfl.geom.Point(0, height - glow.height), null, null, true);
		glow.dispose();
		bitmap.fillRect(new Rectangle(0, 0, EDGE, height), 0xFFFFFFFF);
		bitmap.fillRect(new Rectangle(width - EDGE, 0, EDGE, height), 0xFFFFFFFF);
		return bitmap;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		for (i in 0...lanes.length)
		{
			if (TouchInput.lanePressedAt(i))
				lanes[i].alpha = PRESSED_ALPHA;
			else if (lanes[i].alpha > 0)
			{
				lanes[i].alpha -= lanes[i].alpha * Math.min(1, elapsed * FADE_OUT_SPEED);
				if (lanes[i].alpha < 0.01) lanes[i].alpha = 0;
			}
		}
	}

	override function destroy()
	{
		TouchInput.hitboxEnabled = false;
		if (Controls.instance != null) Controls.instance.controllerMode = false;
		super.destroy();
	}
}
