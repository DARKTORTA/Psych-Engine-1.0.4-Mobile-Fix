package mobile;

#if android
import lime.system.JNI;
#end

#if ios
@:cppFileCode('
extern "C" void psych_ios_import_open(int kind, const char *cacheDir);
extern "C" const char *psych_ios_import_result(int index);
extern "C" const char *psych_ios_import_message(void);
extern "C" int psych_ios_dialog_status(void);
extern "C" void psych_ios_dialog_reset(void);
')
#end
class NativeImport
{
	public static inline final VSLICE:Int = 1;
	public static inline final IMAGES:Int = 2;

	static inline final IDLE:Int = 0;
	static inline final WAITING:Int = 1;
	static inline final DONE:Int = 2;
	static inline final CANCELLED:Int = 3;

	#if android
	static inline final DIALOGS:String = 'org/psychengine/mobile/FileDialogs';
	#end

	static var kind:Int = 0;
	static var polling:Bool = false;
	static var onDone:Array<String>->Void;
	static var onFail:String->Void;
	static var onCancel:Void->Void;

	public static function pick(type:Int, done:Array<String>->Void, fail:String->Void, ?cancel:Void->Void)
	{
		if (polling) return;
		kind = type;
		onDone = done;
		onFail = fail;
		onCancel = cancel;

		var dir:String = cacheDirectory(type == VSLICE ? 'vslice' : 'images');
		#if android
		JNI.createStaticMethod(DIALOGS, 'reset', '()V')();
		JNI.createStaticMethod(DIALOGS, type == VSLICE ? 'openVSlice' : 'openImages', '(Ljava/lang/String;)V')(dir);
		#elseif ios
		untyped __cpp__('psych_ios_dialog_reset()');
		untyped __cpp__('psych_ios_import_open({0}, {1}.utf8_str())', type, dir);
		#end
		polling = true;
		FlxG.signals.postUpdate.add(poll);
	}

	static function cacheDirectory(name:String):String
	{
		var dir:String = haxe.io.Path.addTrailingSlash(lime.system.System.applicationStorageDirectory) + 'file_dialogs/$name/';
		try
		{
			if (FileSystem.exists(dir))
			{
				for (file in FileSystem.readDirectory(dir))
					if (!FileSystem.isDirectory(dir + file)) FileSystem.deleteFile(dir + file);
			}
			else FileSystem.createDirectory(dir);
		}
		catch (e:Dynamic) {}
		return dir;
	}

	static function status():Int
	{
		#if android
		return JNI.createStaticMethod(DIALOGS, 'getStatus', '()I')();
		#elseif ios
		return untyped __cpp__('psych_ios_dialog_status()');
		#else
		return CANCELLED;
		#end
	}

	static function results():Array<String>
	{
		#if android
		if (kind == VSLICE)
			return [
				JNI.createStaticMethod('org/psychengine/mobile/VSliceImport', 'getChartPath', '()Ljava/lang/String;')(),
				JNI.createStaticMethod('org/psychengine/mobile/VSliceImport', 'getMetadataPath', '()Ljava/lang/String;')()
			];
		return [
			JNI.createStaticMethod('org/psychengine/mobile/StageImageImport', 'getImagePath', '()Ljava/lang/String;')(),
			JNI.createStaticMethod('org/psychengine/mobile/StageImageImport', 'getOriginalPath', '()Ljava/lang/String;')()
		];
		#elseif ios
		var first:String = untyped __cpp__('::String(psych_ios_import_result(0))');
		var second:String = untyped __cpp__('::String(psych_ios_import_result(1))');
		return [first, second];
		#else
		return [];
		#end
	}

	static function message():String
	{
		#if android
		var name:String = kind == VSLICE ? 'org/psychengine/mobile/VSliceImport' : 'org/psychengine/mobile/StageImageImport';
		return JNI.createStaticMethod(name, 'getMessage', '()Ljava/lang/String;')();
		#elseif ios
		return untyped __cpp__('::String(psych_ios_import_message())');
		#else
		return '';
		#end
	}

	static function poll()
	{
		var current:Int = status();
		if (current == WAITING || current == IDLE) return;

		polling = false;
		FlxG.signals.postUpdate.remove(poll);

		var paths:Array<String> = current == DONE ? results() : null;
		var text:String = current != DONE && current != CANCELLED ? message() : null;
		#if android
		JNI.createStaticMethod(DIALOGS, 'reset', '()V')();
		#elseif ios
		untyped __cpp__('psych_ios_dialog_reset()');
		#end

		var done = onDone;
		var fail = onFail;
		var cancel = onCancel;
		onDone = null;
		onFail = null;
		onCancel = null;

		if (current == DONE)
		{
			if (done != null) done([for (path in paths) path == null ? '' : path]);
		}
		else if (current == CANCELLED)
		{
			if (cancel != null) cancel();
		}
		else if (fail != null)
			fail(text != null && text.length > 0 ? text : 'Could not read the selected files.');
	}
}
