package org.psychengine.mobile;

import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.Settings;
import java.io.File;
import java.io.IOException;
import org.haxe.extension.Extension;

public class Storage
{
	public static final String FOLDER = ".PsychEngine";
	private static final String EXTERNAL_MARKER = ".use_external";

	public static File getAppDir(Context context)
	{
		File dir = context.getExternalFilesDir(null);
		if (dir == null) dir = context.getFilesDir();
		return dir;
	}

	public static File getPublicDir()
	{
		return new File(Environment.getExternalStorageDirectory(), FOLDER);
	}

	public static boolean hasAccess(Context context)
	{
		if (Build.VERSION.SDK_INT >= 30) return Environment.isExternalStorageManager();
		if (Build.VERSION.SDK_INT >= 23) return context.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED;
		return true;
	}

	public static boolean useExternal(Context context)
	{
		return new File(getAppDir(context), EXTERNAL_MARKER).exists();
	}

	public static File getGameDir(Context context)
	{
		if (useExternal(context) && hasAccess(context))
		{
			File dir = getPublicDir();
			if (!dir.exists()) dir.mkdirs();
			if (dir.isDirectory() && dir.canWrite()) return dir;
		}
		return getAppDir(context);
	}

	public static boolean hasAccess()
	{
		Context context = Extension.mainContext;
		return context != null && hasAccess(context);
	}

	public static boolean useExternal()
	{
		Context context = Extension.mainContext;
		return context != null && useExternal(context);
	}

	public static String getGameDirPath()
	{
		Context context = Extension.mainContext;
		if (context == null) return "";
		return getGameDir(context).getAbsolutePath();
	}

	public static void setUseExternal(boolean value)
	{
		Context context = Extension.mainContext;
		if (context == null) return;
		File marker = new File(getAppDir(context), EXTERNAL_MARKER);
		try
		{
			if (value) marker.createNewFile();
			else marker.delete();
		}
		catch (IOException e) {}
	}

	public static void requestAccess()
	{
		final Activity activity = Extension.mainActivity;
		if (activity == null) return;

		activity.runOnUiThread(new Runnable()
		{
			@Override
			public void run()
			{
				if (Build.VERSION.SDK_INT >= 30)
				{
					try
					{
						Intent intent = new Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION);
						intent.setData(Uri.parse("package:" + activity.getPackageName()));
						activity.startActivity(intent);
					}
					catch (Exception e)
					{
						try
						{
							activity.startActivity(new Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION));
						}
						catch (Exception ignored) {}
					}
				}
				else if (Build.VERSION.SDK_INT >= 23)
				{
					activity.requestPermissions(new String[] {
						Manifest.permission.READ_EXTERNAL_STORAGE,
						Manifest.permission.WRITE_EXTERNAL_STORAGE
					}, 7001);
				}
			}
		});
	}
}
