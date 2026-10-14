package mobile;

import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.FlxState;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import openfl.events.MouseEvent;
import openfl.events.TouchEvent;

typedef TouchPoint =
{
	var id:Int;
	var x:Float;
	var y:Float;
	var startX:Float;
	var startY:Float;
	var lastY:Float;
	var time:Int;
	var button:MobileButton;
	var control:FlxObject;
	var dragging:Bool;
	var beganThisFrame:Bool;
}

typedef PendingTouch =
{
	var type:Int;
	var id:Int;
	var x:Float;
	var y:Float;
}

class TouchInput
{
	public static inline final LANES:Int = 4;
	static inline final SWIPE_DISTANCE:Float = 60;
	static inline final TAP_DISTANCE:Float = 40;
	static inline final DRAG_DISTANCE:Float = 20;
	static inline final BEGIN:Int = 0;
	static inline final MOVE:Int = 1;
	static inline final END:Int = 2;

	public static var hitboxEnabled:Bool = false;
	public static var blockGestures:Bool = false;
	public static var tapX(default, null):Float = 0;
	public static var tapY(default, null):Float = 0;

	static var lanePressed:Array<Bool> = [for (i in 0...LANES) false];
	static var lanePrevious:Array<Bool> = [for (i in 0...LANES) false];

	static var swipeUp:Bool = false;
	static var swipeDown:Bool = false;
	static var swipeLeft:Bool = false;
	static var swipeRight:Bool = false;
	static var tap:Bool = false;
	static var tapConsumed:Bool = false;
	static var backTap:Bool = false;
	static var pauseTap:Bool = false;
	static var dragY:Float = 0;
	static var dragging:Bool = false;
	static var tappedControls:Array<FlxObject> = [];
	static var heldControls:Array<FlxObject> = [];
	static var tappedButtons:Array<MobileButton> = [];

	static var pending:Array<PendingTouch> = [];
	static var points:Map<Int, TouchPoint> = new Map();
	static var buttons:Array<MobileButton> = [];
	static var controls:Array<FlxObject> = [];
	static var frame:Int = 0;
	static var computedFrame:Int = -1;

	static var activeTouches:Int = 0;
	static var primaryBlocked:Bool = false;
	static var initialized:Bool = false;

	public static function init()
	{
		if (initialized) return;
		initialized = true;

		FlxG.stage.addEventListener(TouchEvent.TOUCH_BEGIN, onTouchBegin, false, 1000);
		FlxG.stage.addEventListener(TouchEvent.TOUCH_MOVE, onTouchMove, false, 1000);
		FlxG.stage.addEventListener(TouchEvent.TOUCH_END, onTouchEnd, false, 1000);
		FlxG.stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseEvent, false, 1000);
		FlxG.stage.addEventListener(MouseEvent.MOUSE_UP, onMouseEvent, false, 1000);

		FlxG.signals.preUpdate.add(function() frame++);
		FlxG.signals.postUpdate.add(function() {
			refresh();
			FlxG.mouse.visible = false;
		});
		FlxG.signals.focusLost.add(clearTouches);
	}

	public static function register(button:MobileButton)
	{
		if (!buttons.contains(button)) buttons.push(button);
	}

	public static function unregister(button:MobileButton)
	{
		buttons.remove(button);
		tappedButtons.remove(button);
		for (point in points)
			if (point.button == button) point.button = null;
	}

	public static function addControl(control:FlxObject)
	{
		if (!controls.contains(control)) controls.push(control);
	}

	public static function removeControl(control:FlxObject)
	{
		controls.remove(control);
		heldControls.remove(control);
		tappedControls.remove(control);
		for (point in points)
			if (point.control == control) point.control = null;
	}

	public static function controlTapped(control:FlxObject):Bool
	{
		refresh();
		return tappedControls.contains(control);
	}

	public static function controlHeld(control:FlxObject):Bool
	{
		refresh();
		return heldControls.contains(control);
	}

	public static function buttonTapped(button:MobileButton):Bool
	{
		refresh();
		return tappedButtons.contains(button);
	}

	public static function lanePressedAt(lane:Int):Bool
	{
		refresh();
		return lanePressed[lane];
	}

	public static function justPressed(key:String):Bool
	{
		refresh();
		var lane:Int = laneOf(key);
		if (lane > -1) return lanePressed[lane] && !lanePrevious[lane];

		return switch (key)
		{
			case 'back': backTap;
			case 'pause': pauseTap;
			case 'accept': !blockGestures && tap && !tapConsumed;
			default: !blockGestures && justSwiped(key);
		}
	}

	public static function pressed(key:String):Bool
	{
		refresh();
		var lane:Int = laneOf(key);
		if (lane > -1) return lanePressed[lane];
		return !blockGestures && justSwiped(key);
	}

	public static function justReleased(key:String):Bool
	{
		refresh();
		var lane:Int = laneOf(key);
		return lane > -1 && !lanePressed[lane] && lanePrevious[lane];
	}

	public static function justSwiped(key:String):Bool
	{
		refresh();
		return switch (key)
		{
			case 'ui_up': swipeUp;
			case 'ui_down': swipeDown;
			case 'ui_left': swipeLeft;
			case 'ui_right': swipeRight;
			default: false;
		}
	}

	public static function justTapped():Bool
	{
		refresh();
		return tap;
	}

	public static function consumeTap()
	{
		refresh();
		tapConsumed = true;
	}

	public static function tappedOn(object:FlxObject, ?camera:FlxCamera, padding:Float = 0):Bool
	{
		return justTapped() && overlapsScreen(object, tapX, tapY, camera, padding);
	}

	public static function tappedRow(items:Array<FlxObject>, padding:Float = 10):Int
	{
		if (!justTapped()) return -1;
		for (i in 0...items.length)
		{
			var item:FlxObject = items[i];
			if (item == null || !item.exists || !item.visible) continue;
			var bounds:Array<Float> = screenBounds(item, null);
			if (tapY >= bounds[1] - padding && tapY <= bounds[1] + bounds[3] + padding) return i;
		}
		return -1;
	}

	public static function overlapsScreen(object:FlxObject, x:Float, y:Float, ?camera:FlxCamera, padding:Float = 0):Bool
	{
		if (object == null || !object.exists || !object.visible) return false;
		var bounds:Array<Float> = screenBounds(object, camera);
		return x >= bounds[0] - padding && x <= bounds[0] + bounds[2] + padding && y >= bounds[1] - padding && y <= bounds[1] + bounds[3] + padding;
	}

	public static function dragDeltaY():Float
	{
		refresh();
		return dragY;
	}

	public static function isDragging():Bool
	{
		refresh();
		return dragging;
	}

	public static function isNoteKey(key:String):Bool
	{
		return laneOf(key) > -1;
	}

	static function screenBounds(object:FlxObject, camera:FlxCamera):Array<Float>
	{
		var cam:FlxCamera = cameraOf(object, camera);
		var pos:FlxPoint = object.getScreenPosition(null, cam);
		var marginX:Float = cam.width * 0.5 * (1 - 1 / cam.zoom);
		var marginY:Float = cam.height * 0.5 * (1 - 1 / cam.zoom);
		var bounds:Array<Float> = [cam.x + (pos.x - marginX) * cam.zoom, cam.y + (pos.y - marginY) * cam.zoom, object.width * cam.zoom, object.height * cam.zoom];
		pos.put();
		return bounds;
	}

	@:access(flixel.FlxBasic)
	static function cameraOf(object:FlxBasic, camera:FlxCamera):FlxCamera
	{
		if (camera != null) return camera;
		if (object._cameras != null && object._cameras.length > 0) return object._cameras[0];

		var state:FlxState = FlxG.state;
		var containers:Array<FlxState> = [];
		while (state != null)
		{
			containers.unshift(state);
			state = state.subState;
		}
		for (container in containers)
		{
			var found:Array<FlxCamera> = findCameras(container, object, container._cameras);
			if (found != null && found.length > 0) return found[0];
		}

		var cams:Array<FlxCamera> = object.cameras;
		return (cams != null && cams.length > 0) ? cams[0] : FlxG.camera;
	}

	@:access(flixel.FlxBasic)
	static function findCameras(group:FlxTypedGroup<FlxBasic>, target:FlxBasic, inherited:Array<FlxCamera>):Array<FlxCamera>
	{
		if (group == null || group.members == null) return null;
		for (member in group.members)
		{
			if (member == null) continue;
			var cams:Array<FlxCamera> = member._cameras != null ? member._cameras : inherited;
			if (member == target) return cams;
			if (Std.isOfType(member, FlxTypedGroup))
			{
				var found:Array<FlxCamera> = findCameras(cast member, target, cams);
				if (found != null) return found;
			}
			else if (Std.isOfType(member, FlxTypedSpriteGroup))
			{
				var spriteGroup:FlxTypedSpriteGroup<Dynamic> = cast member;
				var found:Array<FlxCamera> = findCameras(cast spriteGroup.group, target, cams);
				if (found != null) return found;
			}
		}
		return null;
	}

	static function laneOf(key:String):Int
	{
		return switch (key)
		{
			case 'note_left': 0;
			case 'note_down': 1;
			case 'note_up': 2;
			case 'note_right': 3;
			default: -1;
		}
	}

	static function laneAt(x:Float):Int
	{
		var lane:Int = Std.int(x / (FlxG.width / LANES));
		if (lane < 0) lane = 0;
		if (lane >= LANES) lane = LANES - 1;
		return lane;
	}

	static function buttonEnabled(button:MobileButton):Bool
	{
		if (button == null || !button.exists || !button.alive) return false;
		if (button.key == 'pause')
		{
			var sub:FlxState = FlxG.state != null ? FlxG.state.subState : null;
			button.visible = sub == null || Std.isOfType(sub, CustomFadeTransition);
		}
		return button.visible;
	}

	static function buttonAt(x:Float, y:Float):MobileButton
	{
		var i:Int = buttons.length - 1;
		while (i >= 0)
		{
			var button:MobileButton = buttons[i];
			if (buttonEnabled(button) && overlapsScreen(button, x, y)) return button;
			i--;
		}
		return null;
	}

	static function controlAt(x:Float, y:Float):FlxObject
	{
		var i:Int = controls.length - 1;
		while (i >= 0)
		{
			var control:FlxObject = controls[i];
			if (control != null && control.exists && control.alive && overlapsScreen(control, x, y)) return control;
			i--;
		}
		return null;
	}

	static function toGameX(stageX:Float):Float
		return (stageX - FlxG.game.x) / FlxG.scaleMode.scale.x;

	static function toGameY(stageY:Float):Float
		return (stageY - FlxG.game.y) / FlxG.scaleMode.scale.y;

	static function onTouchBegin(e:TouchEvent)
	{
		if (FlxG.game == null || FlxG.scaleMode == null) return;
		var x:Float = toGameX(e.stageX);
		var y:Float = toGameY(e.stageY);
		var onControl:Bool = buttonAt(x, y) != null || controlAt(x, y) != null;
		if (activeTouches == 0) primaryBlocked = onControl;
		activeTouches++;
		pending.push({type: BEGIN, id: e.touchPointID, x: x, y: y});
	}

	static function onTouchMove(e:TouchEvent)
	{
		if (FlxG.game == null || FlxG.scaleMode == null) return;
		pending.push({type: MOVE, id: e.touchPointID, x: toGameX(e.stageX), y: toGameY(e.stageY)});
	}

	static function onTouchEnd(e:TouchEvent)
	{
		if (activeTouches > 0) activeTouches--;
		if (FlxG.game == null || FlxG.scaleMode == null) return;
		pending.push({type: END, id: e.touchPointID, x: toGameX(e.stageX), y: toGameY(e.stageY)});
	}

	static function onMouseEvent(e:MouseEvent)
	{
		if (primaryBlocked) e.stopImmediatePropagation();
	}

	static function clearTouches()
	{
		pending.resize(0);
		points.clear();
		activeTouches = 0;
		primaryBlocked = false;
	}

	static function refresh()
	{
		if (computedFrame == frame) return;
		computedFrame = frame;

		for (i in 0...LANES)
		{
			lanePrevious[i] = lanePressed[i];
			lanePressed[i] = false;
		}
		swipeUp = swipeDown = swipeLeft = swipeRight = tap = tapConsumed = backTap = pauseTap = dragging = false;
		dragY = 0;
		tappedControls.resize(0);
		heldControls.resize(0);
		tappedButtons.resize(0);

		for (point in points)
			point.beganThisFrame = false;

		var events:Array<PendingTouch> = pending;
		pending = [];
		for (event in events)
		{
			switch (event.type)
			{
				case BEGIN:
					var button:MobileButton = buttonAt(event.x, event.y);
					var control:FlxObject = button == null ? controlAt(event.x, event.y) : null;
					if (button != null) button.press();
					points.set(event.id, {
						id: event.id,
						x: event.x,
						y: event.y,
						startX: event.x,
						startY: event.y,
						lastY: event.y,
						time: FlxG.game.ticks,
						button: button,
						control: control,
						dragging: false,
						beganThisFrame: true
					});

				case MOVE:
					var point:TouchPoint = points.get(event.id);
					if (point == null) continue;
					point.x = event.x;
					point.y = event.y;
					if (point.button == null && point.control == null)
					{
						if (!point.dragging && Math.abs(point.y - point.startY) > DRAG_DISTANCE) point.dragging = true;
						if (point.dragging)
						{
							dragY += point.y - point.lastY;
							dragging = true;
						}
						point.lastY = point.y;
					}

				case END:
					var point:TouchPoint = points.get(event.id);
					if (point == null) continue;
					points.remove(event.id);
					point.x = event.x;
					point.y = event.y;
					release(point);
			}
		}

		for (point in points)
		{
			if (point.control != null)
			{
				if (!heldControls.contains(point.control)) heldControls.push(point.control);
				continue;
			}
			if (point.button != null) continue;
			if (point.dragging) dragging = true;
			if (hitboxEnabled) lanePressed[laneAt(point.x)] = true;
		}

		#if android
		if (FlxG.android.justReleased.BACK) backTap = pauseTap = true;
		#end
	}

	static function release(point:TouchPoint)
	{
		if (point.control != null)
		{
			if (overlapsScreen(point.control, point.x, point.y, null, 10)) tappedControls.push(point.control);
			return;
		}

		if (point.button != null)
		{
			if (buttonEnabled(point.button) && overlapsScreen(point.button, point.x, point.y, null, 20))
			{
				tappedButtons.push(point.button);
				if (point.button.key == 'pause') pauseTap = true;
				else backTap = true;
			}
			return;
		}

		if (hitboxEnabled && point.beganThisFrame)
			lanePressed[laneAt(point.startX)] = true;

		var dx:Float = point.x - point.startX;
		var dy:Float = point.y - point.startY;
		var distance:Float = Math.sqrt(dx * dx + dy * dy);
		if (distance >= SWIPE_DISTANCE)
		{
			if (Math.abs(dx) > Math.abs(dy))
			{
				if (dx > 0) swipeRight = true;
				else swipeLeft = true;
			}
			else
			{
				if (dy > 0) swipeDown = true;
				else swipeUp = true;
			}
		}
		else if (distance <= TAP_DISTANCE)
		{
			tap = true;
			tapX = point.x;
			tapY = point.y;
		}
	}
}
