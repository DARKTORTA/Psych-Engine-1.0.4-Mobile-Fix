package org.psychengine.mobile;

import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import org.json.JSONObject;

public class VSliceImport
{
	public static final int TYPE_UNKNOWN = 0;
	public static final int TYPE_CHART = 1;
	public static final int TYPE_METADATA = 2;

	private static volatile String chartPath = "";
	private static volatile String metadataPath = "";
	private static volatile String message = "";

	public static void reset()
	{
		chartPath = "";
		metadataPath = "";
		message = "";
	}

	public static String getChartPath()
	{
		return chartPath;
	}

	public static String getMetadataPath()
	{
		return metadataPath;
	}

	public static String getMessage()
	{
		return message;
	}

	public static boolean isComplete()
	{
		if (chartPath.length() == 0 && metadataPath.length() == 0)
			message = "No V-Slice chart or metadata file was selected.";
		else if (chartPath.length() == 0)
			message = "Select the V-Slice chart file (*-chart.json) together with the metadata.";
		else if (metadataPath.length() == 0)
			message = "Select the V-Slice metadata file (*-metadata.json) together with the chart.";
		else
			message = "";
		return chartPath.length() > 0 && metadataPath.length() > 0;
	}

	public static void register(File file, String name)
	{
		int type = detectType(file, name);
		if (type == TYPE_CHART) chartPath = file.getAbsolutePath();
		else if (type == TYPE_METADATA) metadataPath = file.getAbsolutePath();
	}

	public static int detectType(File file, String name)
	{
		try
		{
			JSONObject json = new JSONObject(readText(file));
			if (json.has("playData") && json.has("timeChanges")) return TYPE_METADATA;
			if (json.has("notes") && json.has("scrollSpeed")) return TYPE_CHART;
		}
		catch (Exception e) {}

		String lower = name == null ? "" : name.toLowerCase();
		if (lower.endsWith("-metadata.json") || lower.contains("metadata")) return TYPE_METADATA;
		if (lower.endsWith("-chart.json") || lower.contains("chart")) return TYPE_CHART;
		return TYPE_UNKNOWN;
	}

	private static String readText(File file) throws Exception
	{
		InputStream input = new FileInputStream(file);
		try
		{
			byte[] bytes = new byte[(int)file.length()];
			int offset = 0;
			while (offset < bytes.length)
			{
				int read = input.read(bytes, offset, bytes.length - offset);
				if (read < 0) break;
				offset += read;
			}
			String text = new String(bytes, 0, offset, StandardCharsets.UTF_8);
			if (text.length() > 0 && text.charAt(0) == '﻿') text = text.substring(1);
			return text;
		}
		finally
		{
			input.close();
		}
	}
}
