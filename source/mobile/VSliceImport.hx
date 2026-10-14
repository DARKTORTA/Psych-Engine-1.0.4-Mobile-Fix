package mobile;

class VSliceImport
{
	public static function pick(done:String->String->Void, fail:String->Void)
	{
		NativeImport.pick(NativeImport.VSLICE, function(paths:Array<String>)
		{
			try
			{
				done(File.getContent(paths[0]), File.getContent(paths[1]));
			}
			catch (e:Dynamic)
			{
				fail(Std.string(e));
			}
		}, fail);
	}
}
