package mobile;

import flixel.graphics.FlxGraphic;
import flixel.input.keyboard.FlxKey;
import openfl.display.BitmapData;
import openfl.display.Shape;

class VirtualPad extends FlxSpriteGroup
{
	public static inline final DPAD_SIZE:Int = 82;
	public static inline final ACTION_SIZE:Int = 90;
	static inline final GAP:Int = 6;
	static inline final MARGIN:Int = 14;

	static final ACTION_COLORS:Array<FlxColor> = [0xFFFF4B5C, 0xFF3FD06B, 0xFF39A6FF, 0xFFFFC23A, 0xFFB15CFF];
	static final ACTION_LABELS:Map<String, String> = ['ESCAPE' => 'ESC', 'ENTER' => 'ENTER', 'SPACE' => 'SPACE', 'BACKSPACE' => 'BKSP'];

	public var onKey:FlxKey->Bool->Void;
	public var buttons(default, null):Array<VirtualPadButton> = [];

	public function new(dpad:Bool, actions:Array<FlxKey>)
	{
		super();

		if (dpad)
		{
			var centerX:Float = MARGIN + DPAD_SIZE * 1.5;
			var centerY:Float = FlxG.height - MARGIN - DPAD_SIZE * 1.5;
			addButton(new VirtualPadButton(centerX - DPAD_SIZE / 2, centerY - DPAD_SIZE * 1.5, UP, DPAD_SIZE, image('up'), arrowGraphic(-90)));
			addButton(new VirtualPadButton(centerX - DPAD_SIZE / 2, centerY + DPAD_SIZE / 2, DOWN, DPAD_SIZE, image('down'), arrowGraphic(90)));
			addButton(new VirtualPadButton(centerX - DPAD_SIZE * 1.5, centerY - DPAD_SIZE / 2, LEFT, DPAD_SIZE, image('left'), arrowGraphic(180)));
			addButton(new VirtualPadButton(centerX + DPAD_SIZE / 2, centerY - DPAD_SIZE / 2, RIGHT, DPAD_SIZE, image('right'), arrowGraphic(0)));
		}

		for (i in 0...actions.length)
		{
			var column:Int = i % 3;
			var row:Int = Std.int(i / 3);
			var x:Float = FlxG.width - MARGIN - (column + 1) * ACTION_SIZE - column * GAP;
			var y:Float = FlxG.height - MARGIN - (row + 1) * ACTION_SIZE - row * GAP;
			if (column == 1) y -= ACTION_SIZE * 0.35;
			var name:String = actions[i].toString();
			var label:String = ACTION_LABELS.exists(name) ? ACTION_LABELS.get(name) : name;
			var custom:FlxGraphic = image(name.toLowerCase());
			if (custom != null) addButton(new VirtualPadButton(x, y, actions[i], ACTION_SIZE, custom));
			else addButton(new VirtualPadButton(x, y, actions[i], ACTION_SIZE, null, actionGraphic(ACTION_COLORS[i % ACTION_COLORS.length]), label));
		}

		scrollFactor.set();
	}

	function addButton(button:VirtualPadButton)
	{
		button.onChange = function(down:Bool) if (onKey != null) onKey(button.key, down);
		buttons.push(button);
		add(button);
	}

	public function releaseAll()
	{
		for (button in buttons) button.release();
	}

	static function image(name:String):FlxGraphic
	{
		return Paths.image('mobile/virtualpad/$name');
	}

	static function arrowGraphic(angle:Int):FlxGraphic
	{
		var key:String = 'virtualpad_arrow_$angle';
		var graphic:FlxGraphic = FlxG.bitmap.get(key);
		if (graphic != null) return graphic;

		var size:Int = DPAD_SIZE;
		var half:Float = size / 2;
		var shape:Shape = new Shape();
		shape.graphics.lineStyle(3, 0xFFFFFF, 0.9);
		shape.graphics.beginFill(0x000000, 0.55);
		shape.graphics.drawRoundRect(2, 2, size - 4, size - 4, 22, 22);
		shape.graphics.endFill();

		var radians:Float = angle * Math.PI / 180;
		var points:Array<Array<Float>> = [[size * 0.26, 0], [-size * 0.16, -size * 0.22], [-size * 0.16, size * 0.22]];
		shape.graphics.lineStyle();
		shape.graphics.beginFill(0xFFFFFF, 0.95);
		for (i in 0...points.length)
		{
			var px:Float = half + points[i][0] * Math.cos(radians) - points[i][1] * Math.sin(radians);
			var py:Float = half + points[i][0] * Math.sin(radians) + points[i][1] * Math.cos(radians);
			if (i == 0) shape.graphics.moveTo(px, py);
			else shape.graphics.lineTo(px, py);
		}
		shape.graphics.endFill();

		return cache(key, shape, size);
	}

	static function actionGraphic(color:FlxColor):FlxGraphic
	{
		var key:String = 'virtualpad_action_${color.toHexString()}';
		var graphic:FlxGraphic = FlxG.bitmap.get(key);
		if (graphic != null) return graphic;

		var size:Int = ACTION_SIZE;
		var shape:Shape = new Shape();
		shape.graphics.lineStyle(4, color.rgb, 1);
		shape.graphics.beginFill(0x000000, 0.55);
		shape.graphics.drawCircle(size / 2, size / 2, size / 2 - 3);
		shape.graphics.endFill();

		return cache(key, shape, size);
	}

	static function cache(key:String, shape:Shape, size:Int):FlxGraphic
	{
		var bitmap:BitmapData = new BitmapData(size, size, true, 0);
		bitmap.draw(shape, null, null, null, null, true);
		var graphic:FlxGraphic = FlxG.bitmap.add(bitmap, false, key);
		graphic.persist = true;
		graphic.destroyOnNoUse = false;
		return graphic;
	}
}

class VirtualPadButton extends FlxSpriteGroup
{
	static inline final IDLE_ALPHA:Float = 0.5;
	static inline final PRESSED_ALPHA:Float = 0.95;

	public var key(default, null):FlxKey;
	public var onChange:Bool->Void;
	public var pressed(default, null):Bool = false;

	var base:FlxSprite;
	var text:FlxText;
	var releaseQueued:Bool = false;
	var baseScale:Float = 1;

	public function new(x:Float, y:Float, key:FlxKey, size:Int, graphic:FlxGraphic, ?fallback:FlxGraphic, ?label:String)
	{
		super(x, y);
		this.key = key;

		base = new FlxSprite().loadGraphic(graphic != null ? graphic : fallback);
		base.setGraphicSize(size, size);
		base.updateHitbox();
		base.antialiasing = ClientPrefs.data.antialiasing;
		add(base);
		baseScale = base.scale.x;

		if (label != null)
		{
			var size:Int = label.length > 3 ? 16 : 22;
			text = new FlxText(0, 0, base.width, label, size);
			text.setFormat(Paths.font('vcr.ttf'), size, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
			text.y = (base.height - text.height) / 2;
			add(text);
		}

		alpha = IDLE_ALPHA;
		scrollFactor.set();
		TouchInput.addControl(this);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (releaseQueued)
		{
			releaseQueued = false;
			setPressed(false);
		}

		var held:Bool = visible && TouchInput.controlHeld(this);
		if (!held && !pressed && visible && TouchInput.controlTapped(this))
		{
			setPressed(true);
			releaseQueued = true;
			return;
		}
		if (!releaseQueued) setPressed(held);
	}

	public function release()
	{
		releaseQueued = false;
		setPressed(false);
	}

	function setPressed(value:Bool)
	{
		if (value == pressed) return;
		pressed = value;
		alpha = value ? PRESSED_ALPHA : IDLE_ALPHA;
		var scale:Float = baseScale * (value ? 0.92 : 1);
		base.scale.set(scale, scale);
		if (onChange != null) onChange(value);
	}

	override function destroy()
	{
		release();
		TouchInput.removeControl(this);
		super.destroy();
	}
}
