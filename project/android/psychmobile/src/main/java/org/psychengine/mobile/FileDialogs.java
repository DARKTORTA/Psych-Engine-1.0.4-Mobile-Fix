package org.psychengine.mobile;

import android.app.Activity;
import android.content.ClipData;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.Environment;
import android.provider.DocumentsContract;
import android.provider.OpenableColumns;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import org.haxe.extension.Extension;

public class FileDialogs extends Extension
{
	public static final int STATUS_IDLE = 0;
	public static final int STATUS_WAITING = 1;
	public static final int STATUS_DONE = 2;
	public static final int STATUS_CANCELLED = 3;
	public static final int STATUS_ERROR = 4;

	private static final int SAVE_REQUEST = 7101;
	private static final int OPEN_REQUEST = 7102;
	private static final int VSLICE_REQUEST = 7103;
	private static final int IMAGES_REQUEST = 7104;

	private static volatile int status = STATUS_IDLE;
	private static volatile String resultPath = "";
	private static volatile String resultName = "";
	private static String pendingSource = null;
	private static String pendingCacheDir = null;

	public static int getStatus()
	{
		return status;
	}

	public static String getResultPath()
	{
		return resultPath;
	}

	public static String getResultName()
	{
		return resultName;
	}

	public static void reset()
	{
		status = STATUS_IDLE;
		resultPath = "";
		resultName = "";
	}

	public static void save(final String sourcePath, final String fileName, final String mimeType)
	{
		final Activity activity = Extension.mainActivity;
		if (activity == null)
		{
			status = STATUS_ERROR;
			return;
		}

		status = STATUS_WAITING;
		pendingSource = sourcePath;
		activity.runOnUiThread(new Runnable()
		{
			@Override
			public void run()
			{
				try
				{
					Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
					intent.addCategory(Intent.CATEGORY_OPENABLE);
					intent.setType(mimeType == null || mimeType.length() == 0 ? "application/octet-stream" : mimeType);
					intent.putExtra(Intent.EXTRA_TITLE, fileName);
					activity.startActivityForResult(intent, SAVE_REQUEST);
				}
				catch (Exception e)
				{
					status = STATUS_ERROR;
				}
			}
		});
	}

	public static void open(final String mimeType, final String cacheDir)
	{
		final Activity activity = Extension.mainActivity;
		if (activity == null)
		{
			status = STATUS_ERROR;
			return;
		}

		status = STATUS_WAITING;
		pendingCacheDir = cacheDir;
		activity.runOnUiThread(new Runnable()
		{
			@Override
			public void run()
			{
				try
				{
					Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
					intent.addCategory(Intent.CATEGORY_OPENABLE);
					intent.setType(mimeType == null || mimeType.length() == 0 ? "*/*" : mimeType);
					activity.startActivityForResult(intent, OPEN_REQUEST);
				}
				catch (Exception e)
				{
					status = STATUS_ERROR;
				}
			}
		});
	}

	public static void openVSlice(final String cacheDir)
	{
		final Activity activity = Extension.mainActivity;
		if (activity == null)
		{
			status = STATUS_ERROR;
			return;
		}

		status = STATUS_WAITING;
		pendingCacheDir = cacheDir;
		VSliceImport.reset();
		activity.runOnUiThread(new Runnable()
		{
			@Override
			public void run()
			{
				try
				{
					Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
					intent.addCategory(Intent.CATEGORY_OPENABLE);
					intent.setType("*/*");
					intent.putExtra(Intent.EXTRA_MIME_TYPES, new String[] { "application/json", "text/plain", "application/octet-stream" });
					intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true);
					activity.startActivityForResult(intent, VSLICE_REQUEST);
				}
				catch (Exception e)
				{
					status = STATUS_ERROR;
				}
			}
		});
	}

	public static void openImages(final String cacheDir)
	{
		final Activity activity = Extension.mainActivity;
		if (activity == null)
		{
			status = STATUS_ERROR;
			return;
		}

		status = STATUS_WAITING;
		pendingCacheDir = cacheDir;
		StageImageImport.reset();
		activity.runOnUiThread(new Runnable()
		{
			@Override
			public void run()
			{
				try
				{
					Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
					intent.addCategory(Intent.CATEGORY_OPENABLE);
					intent.setType("*/*");
					intent.putExtra(Intent.EXTRA_MIME_TYPES, new String[] { "image/png", "text/xml", "application/xml", "application/json", "text/plain", "application/octet-stream" });
					intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true);
					activity.startActivityForResult(intent, IMAGES_REQUEST);
				}
				catch (Exception e)
				{
					status = STATUS_ERROR;
				}
			}
		});
	}

	@Override
	public boolean onActivityResult(int requestCode, int resultCode, Intent data)
	{
		if (requestCode == VSLICE_REQUEST)
		{
			onVSliceResult(resultCode, data);
			return true;
		}
		if (requestCode == IMAGES_REQUEST)
		{
			onImagesResult(resultCode, data);
			return true;
		}
		if (requestCode != SAVE_REQUEST && requestCode != OPEN_REQUEST) return true;

		if (resultCode != Activity.RESULT_OK || data == null || data.getData() == null)
		{
			status = STATUS_CANCELLED;
			return true;
		}

		Uri uri = data.getData();
		try
		{
			if (requestCode == SAVE_REQUEST)
			{
				copy(new FileInputStream(pendingSource), mainActivity.getContentResolver().openOutputStream(uri, "wt"));
				resultPath = uri.toString();
				resultName = queryName(uri);
			}
			else
			{
				String name = queryName(uri);
				File dir = new File(pendingCacheDir);
				if (!dir.exists()) dir.mkdirs();
				File target = new File(dir, name);
				copy(mainActivity.getContentResolver().openInputStream(uri), new FileOutputStream(target));
				resultPath = target.getAbsolutePath();
				resultName = name;
			}
			status = STATUS_DONE;
		}
		catch (Exception e)
		{
			status = STATUS_ERROR;
		}
		return true;
	}

	private static void onVSliceResult(int resultCode, Intent data)
	{
		if (resultCode != Activity.RESULT_OK || data == null)
		{
			status = STATUS_CANCELLED;
			return;
		}

		try
		{
			File dir = new File(pendingCacheDir);
			if (!dir.exists()) dir.mkdirs();

			ClipData clip = data.getClipData();
			if (clip != null)
			{
				for (int i = 0; i < clip.getItemCount(); i++)
					importVSliceFile(clip.getItemAt(i).getUri(), dir);
			}
			else if (data.getData() != null)
				importVSliceFile(data.getData(), dir);

			status = VSliceImport.isComplete() ? STATUS_DONE : STATUS_ERROR;
		}
		catch (Exception e)
		{
			status = STATUS_ERROR;
		}
	}

	private static void importVSliceFile(Uri uri, File dir) throws Exception
	{
		if (uri == null) return;
		String name = queryName(uri);
		File target = new File(dir, name);
		copy(mainActivity.getContentResolver().openInputStream(uri), new FileOutputStream(target));
		VSliceImport.register(target, name);
	}

	private static void onImagesResult(int resultCode, Intent data)
	{
		if (resultCode != Activity.RESULT_OK || data == null)
		{
			status = STATUS_CANCELLED;
			return;
		}

		try
		{
			File dir = new File(pendingCacheDir);
			if (!dir.exists()) dir.mkdirs();

			ClipData clip = data.getClipData();
			if (clip != null)
			{
				for (int i = 0; i < clip.getItemCount(); i++)
					importImageFile(clip.getItemAt(i).getUri(), dir);
			}
			else if (data.getData() != null)
				importImageFile(data.getData(), dir);

			status = StageImageImport.isComplete() ? STATUS_DONE : STATUS_ERROR;
		}
		catch (Exception e)
		{
			status = STATUS_ERROR;
		}
	}

	private static void importImageFile(Uri uri, File dir) throws Exception
	{
		if (uri == null) return;
		String name = queryName(uri);
		File target = new File(dir, name);
		copy(mainActivity.getContentResolver().openInputStream(uri), new FileOutputStream(target));
		StageImageImport.register(target, name, originalPath(uri));
	}

	private static String originalPath(Uri uri)
	{
		try
		{
			String authority = uri.getAuthority();
			if (authority == null || !DocumentsContract.isDocumentUri(mainActivity, uri)) return "";
			String id = DocumentsContract.getDocumentId(uri);
			if (authority.equals(mainActivity.getPackageName() + ".documents")) return id;
			if (authority.equals("com.android.externalstorage.documents"))
			{
				int split = id.indexOf(':');
				if (split > 0 && id.substring(0, split).equalsIgnoreCase("primary"))
					return new File(Environment.getExternalStorageDirectory(), id.substring(split + 1)).getAbsolutePath();
			}
		}
		catch (Exception e) {}
		return "";
	}

	private static String queryName(Uri uri)
	{
		String name = "file";
		Cursor cursor = null;
		try
		{
			cursor = mainActivity.getContentResolver().query(uri, new String[] { OpenableColumns.DISPLAY_NAME }, null, null, null);
			if (cursor != null && cursor.moveToFirst())
			{
				String value = cursor.getString(0);
				if (value != null && value.length() > 0) name = value;
			}
		}
		catch (Exception e) {}
		finally
		{
			if (cursor != null) cursor.close();
		}
		return name.replace('/', '_');
	}

	private static void copy(InputStream input, OutputStream output) throws Exception
	{
		try
		{
			byte[] buffer = new byte[65536];
			int read;
			while ((read = input.read(buffer)) != -1)
				output.write(buffer, 0, read);
			output.flush();
		}
		finally
		{
			try { input.close(); } catch (Exception e) {}
			try { output.close(); } catch (Exception e) {}
		}
	}
}
