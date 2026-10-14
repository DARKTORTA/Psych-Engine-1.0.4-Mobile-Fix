package org.psychengine.mobile;

import android.content.Context;
import android.database.Cursor;
import android.database.MatrixCursor;
import android.os.CancellationSignal;
import android.os.ParcelFileDescriptor;
import android.provider.DocumentsContract.Document;
import android.provider.DocumentsContract.Root;
import android.provider.DocumentsProvider;
import android.webkit.MimeTypeMap;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;

public class DataProvider extends DocumentsProvider
{
	public static final String ROOT_ID = "root";

	private static final String[] DEFAULT_ROOT_PROJECTION = new String[] {
		Root.COLUMN_ROOT_ID,
		Root.COLUMN_MIME_TYPES,
		Root.COLUMN_FLAGS,
		Root.COLUMN_ICON,
		Root.COLUMN_TITLE,
		Root.COLUMN_SUMMARY,
		Root.COLUMN_DOCUMENT_ID,
		Root.COLUMN_AVAILABLE_BYTES
	};

	private static final String[] DEFAULT_DOCUMENT_PROJECTION = new String[] {
		Document.COLUMN_DOCUMENT_ID,
		Document.COLUMN_MIME_TYPE,
		Document.COLUMN_DISPLAY_NAME,
		Document.COLUMN_LAST_MODIFIED,
		Document.COLUMN_FLAGS,
		Document.COLUMN_SIZE
	};


	public static String getAuthority(Context context)
	{
		return context.getPackageName() + ".documents";
	}

	public static File getBaseDir(Context context)
	{
		return Storage.getGameDir(context);
	}

	@Override
	public boolean onCreate()
	{
		return true;
	}

	@Override
	public Cursor queryRoots(String[] projection) throws FileNotFoundException
	{
		File baseDir = getBaseDir(getContext());
		MatrixCursor result = new MatrixCursor(projection != null ? projection : DEFAULT_ROOT_PROJECTION);
		Context context = getContext();
		MatrixCursor.RowBuilder row = result.newRow();
		row.add(Root.COLUMN_ROOT_ID, ROOT_ID);
		row.add(Root.COLUMN_DOCUMENT_ID, getDocId(baseDir));
		row.add(Root.COLUMN_SUMMARY, null);
		row.add(Root.COLUMN_FLAGS, Root.FLAG_SUPPORTS_CREATE | Root.FLAG_LOCAL_ONLY | Root.FLAG_SUPPORTS_IS_CHILD);
		row.add(Root.COLUMN_TITLE, context.getApplicationInfo().loadLabel(context.getPackageManager()).toString());
		row.add(Root.COLUMN_MIME_TYPES, "*/*");
		row.add(Root.COLUMN_AVAILABLE_BYTES, baseDir.getFreeSpace());
		row.add(Root.COLUMN_ICON, context.getApplicationInfo().icon);
		return result;
	}

	@Override
	public Cursor queryDocument(String documentId, String[] projection) throws FileNotFoundException
	{
		MatrixCursor result = new MatrixCursor(projection != null ? projection : DEFAULT_DOCUMENT_PROJECTION);
		includeFile(result, getFile(documentId));
		return result;
	}

	@Override
	public Cursor queryChildDocuments(String parentDocumentId, String[] projection, String sortOrder) throws FileNotFoundException
	{
		MatrixCursor result = new MatrixCursor(projection != null ? projection : DEFAULT_DOCUMENT_PROJECTION);
		File[] children = getFile(parentDocumentId).listFiles();
		if (children != null)
			for (File file : children)
				includeFile(result, file);
		return result;
	}

	@Override
	public ParcelFileDescriptor openDocument(String documentId, String mode, CancellationSignal signal) throws FileNotFoundException
	{
		return ParcelFileDescriptor.open(getFile(documentId), ParcelFileDescriptor.parseMode(mode));
	}

	@Override
	public String createDocument(String parentDocumentId, String mimeType, String displayName) throws FileNotFoundException
	{
		File parent = getFile(parentDocumentId);
		File file = uniqueFile(parent, displayName);
		try
		{
			boolean created = Document.MIME_TYPE_DIR.equals(mimeType) ? file.mkdirs() : file.createNewFile();
			if (!created) throw new FileNotFoundException("Could not create " + displayName);
		}
		catch (IOException e)
		{
			throw new FileNotFoundException(e.getMessage());
		}
		return getDocId(file);
	}

	@Override
	public void deleteDocument(String documentId) throws FileNotFoundException
	{
		File baseDir = getBaseDir(getContext());
		File file = getFile(documentId);
		if (file.equals(baseDir) || !deleteRecursive(file))
			throw new FileNotFoundException("Could not delete " + documentId);
	}

	@Override
	public String renameDocument(String documentId, String displayName) throws FileNotFoundException
	{
		File baseDir = getBaseDir(getContext());
		File file = getFile(documentId);
		File target = uniqueFile(file.getParentFile(), displayName);
		if (file.equals(baseDir) || !file.renameTo(target))
			throw new FileNotFoundException("Could not rename " + documentId);
		return getDocId(target);
	}

	@Override
	public boolean isChildDocument(String parentDocumentId, String documentId)
	{
		return documentId.equals(parentDocumentId) || documentId.startsWith(parentDocumentId + File.separator);
	}

	@Override
	public String getDocumentType(String documentId) throws FileNotFoundException
	{
		return getMimeType(getFile(documentId));
	}

	private void includeFile(MatrixCursor result, File file)
	{
		File baseDir = getBaseDir(getContext());
		int flags = 0;
		if (file.isDirectory())
		{
			flags |= Document.FLAG_DIR_SUPPORTS_CREATE;
			if (!file.equals(baseDir)) flags |= Document.FLAG_SUPPORTS_DELETE | Document.FLAG_SUPPORTS_RENAME;
		}
		else
		{
			flags |= Document.FLAG_SUPPORTS_WRITE | Document.FLAG_SUPPORTS_DELETE | Document.FLAG_SUPPORTS_RENAME;
		}

		MatrixCursor.RowBuilder row = result.newRow();
		row.add(Document.COLUMN_DOCUMENT_ID, getDocId(file));
		row.add(Document.COLUMN_DISPLAY_NAME, file.equals(baseDir) ? getContext().getApplicationInfo().loadLabel(getContext().getPackageManager()).toString() : file.getName());
		row.add(Document.COLUMN_SIZE, file.length());
		row.add(Document.COLUMN_MIME_TYPE, getMimeType(file));
		row.add(Document.COLUMN_LAST_MODIFIED, file.lastModified());
		row.add(Document.COLUMN_FLAGS, flags);
	}

	private String getDocId(File file)
	{
		return file.getAbsolutePath();
	}

	private File getFile(String documentId) throws FileNotFoundException
	{
		File baseDir = getBaseDir(getContext());
		File file = new File(documentId);
		try
		{
			String base = baseDir.getCanonicalPath();
			String path = file.getCanonicalPath();
			if (!path.equals(base) && !path.startsWith(base + File.separator))
				throw new FileNotFoundException(documentId);
		}
		catch (IOException e)
		{
			throw new FileNotFoundException(documentId);
		}
		if (!file.exists()) throw new FileNotFoundException(documentId);
		return file;
	}

	private static String getMimeType(File file)
	{
		if (file.isDirectory()) return Document.MIME_TYPE_DIR;
		String name = file.getName();
		int dot = name.lastIndexOf('.');
		if (dot >= 0)
		{
			String mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(name.substring(dot + 1).toLowerCase());
			if (mime != null) return mime;
		}
		return "application/octet-stream";
	}

	private static File uniqueFile(File parent, String displayName)
	{
		File file = new File(parent, displayName);
		int count = 1;
		while (file.exists())
		{
			int dot = displayName.lastIndexOf('.');
			String name = dot > 0 ? displayName.substring(0, dot) + " (" + count + ")" + displayName.substring(dot) : displayName + " (" + count + ")";
			file = new File(parent, name);
			count++;
		}
		return file;
	}

	private static boolean deleteRecursive(File file)
	{
		File[] children = file.listFiles();
		if (children != null)
			for (File child : children)
				deleteRecursive(child);
		return file.delete();
	}
}
