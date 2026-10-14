package org.psychengine.mobile;

import java.io.File;
import org.haxe.extension.Extension;

public class StageImageImport
{
	private static volatile String imagePath = "";
	private static volatile String originalPath = "";
	private static volatile String message = "";

	public static void reset()
	{
		imagePath = "";
		originalPath = "";
		message = "";
	}

	public static String getImagePath()
	{
		return imagePath;
	}

	public static String getOriginalPath()
	{
		return originalPath;
	}

	public static String getMessage()
	{
		return message;
	}

	public static boolean isComplete()
	{
		if (imagePath.length() == 0)
			message = "Select the PNG image (and its XML/JSON/TXT for animated sprites).";
		else
			message = "";
		return imagePath.length() > 0;
	}

	public static void register(File copied, String name, String original)
	{
		String lower = name == null ? "" : name.toLowerCase();
		if (!lower.endsWith(".png")) return;

		imagePath = copied.getAbsolutePath();
		originalPath = "";
		if (original != null && original.length() > 0)
		{
			File source = new File(original);
			File base = Storage.getGameDir(Extension.mainContext);
			try
			{
				String basePath = base.getCanonicalPath() + File.separator;
				if (source.exists() && source.getCanonicalPath().startsWith(basePath))
					originalPath = source.getAbsolutePath();
			}
			catch (Exception e) {}
		}
	}
}
