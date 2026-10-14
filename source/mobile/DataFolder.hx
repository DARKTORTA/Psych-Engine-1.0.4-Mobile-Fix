package mobile;

#if android
import lime.system.JNI;
#end

class DataFolder
{
	#if android
	static var openJNI:Dynamic = null;
	#end

	public static function open(folder:String = 'mods')
	{
		#if android
		if (openJNI == null)
			openJNI = JNI.createStaticMethod('org/psychengine/mobile/DataFolder', 'open', '(Ljava/lang/String;)V');
		if (openJNI != null) openJNI(folder);
		#elseif ios
		var path:String = haxe.io.Path.addTrailingSlash(lime.system.System.documentsDirectory);
		if (folder != null && folder.length > 0)
		{
			var target:String = path + folder;
			try
			{
				if (!FileSystem.exists(target)) FileSystem.createDirectory(target);
				path = haxe.io.Path.addTrailingSlash(target);
			}
			catch (e:Dynamic) {}
		}
		lime.system.System.openURL('shareddocuments://' + StringTools.urlEncode(path).replace('%2F', '/'));
		#end
	}
}
