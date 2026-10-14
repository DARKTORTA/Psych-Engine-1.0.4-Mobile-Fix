package mobile;

import haxe.io.Bytes;
import haxe.io.Path;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.net.FileFilter;
import openfl.net.FileReference;
#if android
import lime.system.JNI;
#end

#if ios
@:build(mobile.NativeBuild.addFiles('project/ios', 'mm', 'psych_ios'))
@:cppFileCode('
extern "C" void psych_ios_dialog_reset(void);
extern "C" int psych_ios_dialog_status(void);
extern "C" const char *psych_ios_dialog_result(void);
extern "C" void psych_ios_dialog_save(const char *sourcePath);
extern "C" void psych_ios_dialog_open(const char *cacheDir);
')
#end
class MobileFileReference extends FileReference
{
	static inline final IDLE:Int = 0;
	static inline final WAITING:Int = 1;
	static inline final DONE:Int = 2;
	static inline final CANCELLED:Int = 3;

	#if android
	static inline final CLASS:String = 'org/psychengine/mobile/FileDialogs';
	static var jniCache:Map<String, Dynamic> = new Map();

	static function jni(name:String, signature:String):Dynamic
	{
		var key:String = name + signature;
		if (!jniCache.exists(key))
			jniCache.set(key, JNI.createStaticMethod(CLASS, name, signature));
		return jniCache.get(key);
	}
	#end

	var opening:Bool = false;
	var polling:Bool = false;

	public function new()
	{
		super();
	}

	static function tempDirectory(?sub:String = ''):String
	{
		var dir:String = Path.addTrailingSlash(lime.system.System.applicationStorageDirectory) + 'file_dialogs/' + sub;
		if (!FileSystem.exists(dir)) FileSystem.createDirectory(dir);
		return Path.addTrailingSlash(dir);
	}

	static function mimeFor(fileName:String):String
	{
		return switch (Path.extension(fileName == null ? '' : fileName).toLowerCase())
		{
			case 'json': 'application/json';
			case 'txt': 'text/plain';
			case 'xml': 'text/xml';
			case 'lua': 'text/x-lua';
			case 'png': 'image/png';
			case 'ogg': 'audio/ogg';
			default: 'application/octet-stream';
		}
	}

	static function nativeReset()
	{
		#if android
		jni('reset', '()V')();
		#elseif ios
		untyped __cpp__('psych_ios_dialog_reset()');
		#end
	}

	static function nativeStatus():Int
	{
		#if android
		return jni('getStatus', '()I')();
		#elseif ios
		return untyped __cpp__('psych_ios_dialog_status()');
		#else
		return CANCELLED;
		#end
	}

	static function nativeResult():String
	{
		#if android
		return jni('getResultPath', '()Ljava/lang/String;')();
		#elseif ios
		return untyped __cpp__('::String(psych_ios_dialog_result())');
		#else
		return '';
		#end
	}

	override public function save(data:Dynamic, defaultFileName:String = null):Void
	{
		if (defaultFileName == null || defaultFileName.length == 0) defaultFileName = 'file';
		defaultFileName = Path.withoutDirectory(defaultFileName);
		var bytes:Bytes = Std.isOfType(data, Bytes) ? cast data : Bytes.ofString(Std.string(data));

		try
		{
			opening = false;
			nativeReset();
			@:privateAccess this.name = defaultFileName;
			#if android
			var tempPath:String = tempDirectory() + 'pending_save';
			File.saveBytes(tempPath, bytes);
			jni('save', '(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V')(tempPath, defaultFileName, mimeFor(defaultFileName));
			#elseif ios
			var tempPath:String = tempDirectory('export') + defaultFileName;
			File.saveBytes(tempPath, bytes);
			untyped __cpp__('psych_ios_dialog_save({0}.utf8_str())', tempPath);
			#end
			startPolling();
		}
		catch (e:Dynamic)
		{
			dispatchEvent(new IOErrorEvent(IOErrorEvent.IO_ERROR));
		}
	}

	override public function browse(typeFilter:Array<FileFilter> = null):Bool
	{
		@:privateAccess this.__path = null;
		@:privateAccess this.__data = null;
		opening = true;
		nativeReset();
		#if android
		jni('open', '(Ljava/lang/String;Ljava/lang/String;)V')('*/*', tempDirectory('import'));
		#elseif ios
		var cacheDir:String = tempDirectory('import');
		untyped __cpp__('psych_ios_dialog_open({0}.utf8_str())', cacheDir);
		#end
		startPolling();
		return true;
	}

	function startPolling()
	{
		if (polling) return;
		polling = true;
		FlxG.signals.postUpdate.add(poll);
	}

	function stopPolling()
	{
		if (!polling) return;
		polling = false;
		FlxG.signals.postUpdate.remove(poll);
	}

	function poll()
	{
		var status:Int = nativeStatus();
		if (status == WAITING || status == IDLE) return;

		stopPolling();
		var path:String = status == DONE && opening ? nativeResult() : null;
		nativeReset();

		if (status == DONE)
		{
			if (path != null)
			{
				@:privateAccess this.__path = path;
				@:privateAccess this.name = Path.withoutDirectory(path);
				try
				{
					@:privateAccess this.__data = openfl.utils.ByteArray.fromBytes(File.getBytes(path));
				}
				catch (e:Dynamic) {}
			}
			dispatchEvent(new Event(Event.COMPLETE));
		}
		else if (status == CANCELLED)
			dispatchEvent(new Event(Event.CANCEL));
		else
			dispatchEvent(new IOErrorEvent(IOErrorEvent.IO_ERROR));
	}
}
