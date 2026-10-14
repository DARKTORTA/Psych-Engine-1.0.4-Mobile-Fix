package mobile;

@:keep
@:build(mobile.NativeBuild.addFiles('project/lua51/src', 'c', 'psych_lua51'))
class LuaSource
{
	public static function init() {}
}
