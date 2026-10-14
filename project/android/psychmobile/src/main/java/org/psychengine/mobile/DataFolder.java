package org.psychengine.mobile;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.net.Uri;
import android.provider.DocumentsContract;
import android.widget.Toast;
import java.io.File;
import org.haxe.extension.Extension;

public class DataFolder
{
	private static final String[] FILE_MANAGERS = new String[] {
		"com.google.android.documentsui",
		"com.android.documentsui",
		null
	};

	public static void open(final String folder)
	{
		final Activity activity = Extension.mainActivity;
		if (activity == null) return;

		activity.runOnUiThread(new Runnable()
		{
			@Override
			public void run()
			{
				String authority = DataProvider.getAuthority(activity);
				File base = DataProvider.getBaseDir(activity);
				File target = (folder == null || folder.length() == 0) ? base : new File(base, folder);
				if (!target.exists()) target.mkdirs();
				if (!target.isDirectory()) target = base;

				Uri folderUri = DocumentsContract.buildDocumentUri(authority, target.getAbsolutePath());
				Uri rootUri = DocumentsContract.buildRootUri(authority, DataProvider.ROOT_ID);

				for (String manager : FILE_MANAGERS)
					if (tryOpen(activity, folderUri, DocumentsContract.Document.MIME_TYPE_DIR, manager)) return;

				for (String manager : FILE_MANAGERS)
					if (tryOpen(activity, rootUri, "vnd.android.document/root", manager)) return;

				Toast.makeText(activity, "No file manager could open the data folder.", Toast.LENGTH_LONG).show();
			}
		});
	}

	private static boolean tryOpen(Activity activity, Uri uri, String type, String manager)
	{
		Intent intent = new Intent(Intent.ACTION_VIEW);
		intent.setDataAndType(uri, type);
		intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION | Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION | Intent.FLAG_GRANT_PREFIX_URI_PERMISSION);
		if (manager != null) intent.setPackage(manager);
		try
		{
			activity.startActivity(intent);
			return true;
		}
		catch (ActivityNotFoundException e)
		{
			return false;
		}
		catch (SecurityException e)
		{
			return false;
		}
	}
}
