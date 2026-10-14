package mobile;

#if android
import lime.system.JNI;
#end

class StorageUtil
{
	#if android
	static inline final CLASS:String = 'org/psychengine/mobile/Storage';
	static var jniCache:Map<String, Dynamic> = new Map();

	static function jni(name:String, signature:String):Dynamic
	{
		var key:String = name + signature;
		if (!jniCache.exists(key))
			jniCache.set(key, JNI.createStaticMethod(CLASS, name, signature));
		return jniCache.get(key);
	}
	#end

	public static function getGameDir():String
	{
		#if android
		var path:String = jni('getGameDirPath', '()Ljava/lang/String;')();
		if (path != null && path.length > 0) return haxe.io.Path.addTrailingSlash(path);
		return haxe.io.Path.addTrailingSlash(lime.system.System.applicationStorageDirectory);
		#elseif ios
		return haxe.io.Path.addTrailingSlash(lime.system.System.documentsDirectory);
		#else
		return haxe.io.Path.addTrailingSlash(Sys.getCwd());
		#end
	}

	public static function useExternal():Bool
	{
		#if android
		return jni('useExternal', '()Z')() == true;
		#else
		return false;
		#end
	}

	public static function hasAccess():Bool
	{
		#if android
		return jni('hasAccess', '()Z')() == true;
		#else
		return true;
		#end
	}

	public static function requestAccess()
	{
		#if android
		jni('requestAccess', '()V')();
		#end
	}

	public static function setUseExternal(value:Bool)
	{
		#if android
		jni('setUseExternal', '(Z)V')(value);
		#end
	}

	public static function applyGameDir()
	{
		Sys.setCwd(getGameDir());
		#if mobile
		Paths.resetModsRoot();
		#end
	}
}
