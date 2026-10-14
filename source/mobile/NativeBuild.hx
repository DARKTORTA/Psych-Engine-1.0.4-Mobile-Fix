package mobile;

#if macro
import haxe.io.Path;
import haxe.macro.Context;
import haxe.macro.Expr;
import sys.FileSystem;
#end

class NativeBuild
{
	#if macro
	public static function addFiles(folder:String, extension:String, group:String):Array<Field>
	{
		var sourceFile:String = Context.getPosInfos(Context.currentPos()).file;
		var root:String = Path.normalize(FileSystem.absolutePath(Path.directory(sourceFile) + '/../..'));
		var dir:String = Path.normalize(root + '/' + folder);
		var files:String = '';
		for (file in FileSystem.readDirectory(dir))
			if (StringTools.endsWith(file, '.' + extension))
				files += '<file name="$dir/$file" />';

		var xml:String = '<files id="$group">$files</files><target id="haxe"><files id="$group" /></target>';
		Context.getLocalClass().get().meta.add(':buildXml', [macro $v{xml}], Context.currentPos());
		return Context.getBuildFields();
	}
	#end
}
