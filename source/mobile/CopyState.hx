package mobile;

import flixel.FlxState;
import haxe.io.Bytes;
import haxe.io.Path;
import lime.app.Application;
import lime.utils.Assets as LimeAssets;
import states.TitleState;
import sys.thread.Mutex;
import sys.thread.Thread;

class CopyState extends FlxState
{
	static inline final MARKER:String = '.psych_assets';

	var files:Array<String> = [];
	var copied:Int = 0;
	var failed:Int = 0;
	var finished:Bool = false;
	var leaving:Bool = false;
	var mutex:Mutex = new Mutex();

	var bar:FlxSprite;
	var status:FlxText;

	public static function needsCopy():Bool
	{
		try
		{
			return !FileSystem.exists(MARKER) || File.getContent(MARKER) != versionTag();
		}
		catch (e:Dynamic)
		{
			return true;
		}
	}

	static function versionTag():String
	{
		return Application.current.meta.get('version') + ':' + listFiles().length;
	}

	static function listFiles():Array<String>
	{
		return LimeAssets.list().filter(function(id:String) {
			if (id.startsWith('assets/embed/')) return false;
			return id.startsWith('assets/') || id.startsWith('mods/') || id == 'modsList.txt';
		});
	}

	override function create()
	{
		super.create();

		files = listFiles();

		var title:FlxText = new FlxText(0, FlxG.height * 0.38, FlxG.width, 'Preparing game files...');
		title.setFormat(null, 32, FlxColor.WHITE, CENTER);
		add(title);

		var barBg:FlxSprite = new FlxSprite(FlxG.width * 0.15, FlxG.height * 0.5).makeGraphic(Std.int(FlxG.width * 0.7), 24, 0xFF333333);
		add(barBg);

		bar = new FlxSprite(barBg.x, barBg.y).makeGraphic(Std.int(barBg.width), 24, FlxColor.WHITE);
		bar.origin.set(0, 0);
		bar.scale.x = 0;
		add(bar);

		status = new FlxText(0, barBg.y + 40, FlxG.width, '');
		status.setFormat(null, 20, 0xFFAAAAAA, CENTER);
		add(status);

		Thread.create(copyAll);
	}

	function copyAll()
	{
		for (id in files)
		{
			var ok:Bool = true;
			try
			{
				copyFile(id);
			}
			catch (e:Dynamic)
			{
				ok = false;
			}
			mutex.acquire();
			copied++;
			if (!ok) failed++;
			mutex.release();
		}
		mutex.acquire();
		finished = true;
		mutex.release();
	}

	function copyFile(id:String)
	{
		if (!id.startsWith('assets/') && FileSystem.exists(id))
			return;

		var bytes:Bytes = LimeAssets.getBytes(id);
		if (bytes == null)
		{
			var text:String = LimeAssets.getText(id);
			if (text == null) throw 'Missing asset: $id';
			bytes = Bytes.ofString(text);
		}

		var dir:String = Path.directory(id);
		if (dir.length > 0 && !FileSystem.exists(dir))
			FileSystem.createDirectory(dir);

		File.saveBytes(id, bytes);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		mutex.acquire();
		var done:Int = copied;
		var errors:Int = failed;
		var complete:Bool = finished;
		mutex.release();

		var total:Int = files.length;
		bar.scale.x = total > 0 ? done / total : 1;
		status.text = '$done / $total' + (errors > 0 ? ' ($errors failed)' : '');

		if (complete && !leaving)
		{
			leaving = true;
			try
			{
				File.saveContent(MARKER, versionTag());
			}
			catch (e:Dynamic) {}

			#if LUA_ALLOWED
			Mods.pushGlobalMods();
			#end
			Mods.loadTopMod();
			FlxG.switchState(new TitleState());
		}
	}
}
