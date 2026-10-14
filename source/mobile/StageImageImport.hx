package mobile;

class StageImageImport
{
	public static function pick(done:String->Void, fail:String->Void, cancel:Void->Void)
	{
		NativeImport.pick(NativeImport.IMAGES, function(paths:Array<String>)
		{
			var original:String = paths.length > 1 ? paths[1] : '';
			done(original != null && original.length > 0 && FileSystem.exists(original) ? original : paths[0]);
		}, fail, cancel);
	}
}
