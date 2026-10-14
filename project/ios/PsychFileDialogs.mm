#import <UIKit/UIKit.h>
#include <string.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

enum
{
	PSYCH_STATUS_IDLE = 0,
	PSYCH_STATUS_WAITING = 1,
	PSYCH_STATUS_DONE = 2,
	PSYCH_STATUS_CANCELLED = 3,
	PSYCH_STATUS_ERROR = 4
};

static volatile int psychDialogStatus = PSYCH_STATUS_IDLE;
static char psychDialogResult[4096] = {0};
static char psychDialogCacheDir[2048] = {0};
static BOOL psychDialogOpening = NO;

enum
{
	PSYCH_IMPORT_NONE = 0,
	PSYCH_IMPORT_VSLICE = 1,
	PSYCH_IMPORT_IMAGES = 2
};

static int psychImportKind = PSYCH_IMPORT_NONE;
static char psychImportSlots[2][4096] = {{0}, {0}};
static char psychImportMessage[512] = {0};

static void psychCopyText(char *target, size_t size, const char *value)
{
	strncpy(target, value ? value : "", size - 1);
	target[size - 1] = 0;
}

static void psychImportReset(void)
{
	psychCopyText(psychImportSlots[0], sizeof(psychImportSlots[0]), "");
	psychCopyText(psychImportSlots[1], sizeof(psychImportSlots[1]), "");
	psychCopyText(psychImportMessage, sizeof(psychImportMessage), "");
}

static NSString *psychResolvedPath(NSString *path)
{
	NSString *resolved = [[path stringByStandardizingPath] stringByResolvingSymlinksInPath];
	if ([resolved hasPrefix:@"/private/"]) resolved = [resolved substringFromIndex:8];
	return resolved;
}

static BOOL psychIsInsideDocuments(NSString *path)
{
	NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
	if (documents == nil || path == nil) return NO;
	NSString *base = psychResolvedPath(documents);
	NSString *target = psychResolvedPath(path);
	return [target hasPrefix:[base stringByAppendingString:@"/"]];
}

static int psychDetectVSlice(NSString *path)
{
	NSData *data = [NSData dataWithContentsOfFile:path];
	if (data != nil)
	{
		id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
		if ([json isKindOfClass:[NSDictionary class]])
		{
			NSDictionary *dict = (NSDictionary *)json;
			if (dict[@"playData"] != nil && dict[@"timeChanges"] != nil) return 2;
			if (dict[@"notes"] != nil && dict[@"scrollSpeed"] != nil) return 1;
		}
	}

	NSString *name = path.lastPathComponent.lowercaseString;
	if ([name containsString:@"metadata"]) return 2;
	if ([name containsString:@"chart"]) return 1;
	return 0;
}

static void psychFinishImport(NSArray<NSURL *> *urls)
{
	psychImportReset();
	NSFileManager *manager = [NSFileManager defaultManager];
	NSString *cacheDir = [NSString stringWithUTF8String:psychDialogCacheDir];
	[manager createDirectoryAtPath:cacheDir withIntermediateDirectories:YES attributes:nil error:nil];

	for (NSURL *url in urls)
	{
		BOOL scoped = [url startAccessingSecurityScopedResource];
		NSString *original = url.path;
		NSString *target = [cacheDir stringByAppendingPathComponent:url.lastPathComponent];
		[manager removeItemAtPath:target error:nil];
		BOOL copied = [manager copyItemAtPath:original toPath:target error:nil];
		if (scoped) [url stopAccessingSecurityScopedResource];
		if (!copied) continue;

		if (psychImportKind == PSYCH_IMPORT_VSLICE)
		{
			int type = psychDetectVSlice(target);
			if (type == 1) psychCopyText(psychImportSlots[0], sizeof(psychImportSlots[0]), target.UTF8String);
			else if (type == 2) psychCopyText(psychImportSlots[1], sizeof(psychImportSlots[1]), target.UTF8String);
		}
		else if (psychImportKind == PSYCH_IMPORT_IMAGES && [target.pathExtension.lowercaseString isEqualToString:@"png"])
		{
			psychCopyText(psychImportSlots[0], sizeof(psychImportSlots[0]), target.UTF8String);
			psychCopyText(psychImportSlots[1], sizeof(psychImportSlots[1]), psychIsInsideDocuments(original) ? psychResolvedPath(original).UTF8String : "");
		}
	}

	BOOL first = psychImportSlots[0][0] != 0;
	BOOL second = psychImportSlots[1][0] != 0;
	if (psychImportKind == PSYCH_IMPORT_VSLICE)
	{
		if (!first && !second) psychCopyText(psychImportMessage, sizeof(psychImportMessage), "No V-Slice chart or metadata file was selected.");
		else if (!first) psychCopyText(psychImportMessage, sizeof(psychImportMessage), "Select the V-Slice chart file (*-chart.json) together with the metadata.");
		else if (!second) psychCopyText(psychImportMessage, sizeof(psychImportMessage), "Select the V-Slice metadata file (*-metadata.json) together with the chart.");
		psychDialogStatus = first && second ? PSYCH_STATUS_DONE : PSYCH_STATUS_ERROR;
	}
	else
	{
		if (!first) psychCopyText(psychImportMessage, sizeof(psychImportMessage), "Select the PNG image (and its XML/JSON/TXT for animated sprites).");
		psychDialogStatus = first ? PSYCH_STATUS_DONE : PSYCH_STATUS_ERROR;
	}
	psychImportKind = PSYCH_IMPORT_NONE;
}

static void psychSetResult(const char *value)
{
	strncpy(psychDialogResult, value ? value : "", sizeof(psychDialogResult) - 1);
	psychDialogResult[sizeof(psychDialogResult) - 1] = 0;
}

static UIViewController *psychTopController(void)
{
	UIWindow *window = nil;
	for (UIWindow *candidate in [UIApplication sharedApplication].windows)
	{
		if (candidate.isKeyWindow)
		{
			window = candidate;
			break;
		}
	}
	if (window == nil) window = [UIApplication sharedApplication].windows.firstObject;

	UIViewController *controller = window.rootViewController;
	while (controller.presentedViewController != nil)
		controller = controller.presentedViewController;
	return controller;
}

@interface PsychDocumentDelegate : NSObject <UIDocumentPickerDelegate>
@end

@implementation PsychDocumentDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls
{
	if (psychImportKind != PSYCH_IMPORT_NONE)
	{
		if (urls.count == 0) psychDialogStatus = PSYCH_STATUS_CANCELLED;
		else psychFinishImport(urls);
		return;
	}

	NSURL *url = urls.firstObject;
	if (url == nil)
	{
		psychDialogStatus = PSYCH_STATUS_CANCELLED;
		return;
	}

	if (!psychDialogOpening)
	{
		psychSetResult(url.path.UTF8String);
		psychDialogStatus = PSYCH_STATUS_DONE;
		return;
	}

	BOOL scoped = [url startAccessingSecurityScopedResource];
	NSFileManager *manager = [NSFileManager defaultManager];
	NSString *cacheDir = [NSString stringWithUTF8String:psychDialogCacheDir];
	[manager createDirectoryAtPath:cacheDir withIntermediateDirectories:YES attributes:nil error:nil];
	NSString *target = [cacheDir stringByAppendingPathComponent:url.lastPathComponent];
	[manager removeItemAtPath:target error:nil];

	NSError *error = nil;
	BOOL copied = [manager copyItemAtPath:url.path toPath:target error:&error];
	if (scoped) [url stopAccessingSecurityScopedResource];

	if (copied)
	{
		psychSetResult(target.UTF8String);
		psychDialogStatus = PSYCH_STATUS_DONE;
	}
	else psychDialogStatus = PSYCH_STATUS_ERROR;
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url
{
	[self documentPicker:controller didPickDocumentsAtURLs:@[url]];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller
{
	psychImportKind = PSYCH_IMPORT_NONE;
	psychDialogStatus = PSYCH_STATUS_CANCELLED;
}

@end

static PsychDocumentDelegate *psychDocumentDelegate = nil;

static void psychPresentPicker(UIDocumentPickerViewController *picker)
{
	if (psychDocumentDelegate == nil) psychDocumentDelegate = [[PsychDocumentDelegate alloc] init];
	picker.delegate = psychDocumentDelegate;
	picker.modalPresentationStyle = UIModalPresentationFormSheet;

	UIViewController *top = psychTopController();
	if (top == nil)
	{
		psychDialogStatus = PSYCH_STATUS_ERROR;
		return;
	}
	[top presentViewController:picker animated:YES completion:nil];
	#if !__has_feature(objc_arc)
	[picker release];
	#endif
}

extern "C" void psych_ios_import_open(int kind, const char *cacheDir)
{
	psychDialogStatus = PSYCH_STATUS_WAITING;
	psychDialogOpening = YES;
	psychImportKind = kind;
	psychImportReset();
	psychCopyText(psychDialogCacheDir, sizeof(psychDialogCacheDir), cacheDir);
	dispatch_async(dispatch_get_main_queue(), ^{
		UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.item"] inMode:UIDocumentPickerModeOpen];
		if (@available(iOS 11.0, *)) picker.allowsMultipleSelection = YES;
		psychPresentPicker(picker);
	});
}

extern "C" const char *psych_ios_import_result(int index)
{
	return (index == 0 || index == 1) ? psychImportSlots[index] : "";
}

extern "C" const char *psych_ios_import_message(void)
{
	return psychImportMessage;
}

extern "C" void psych_ios_dialog_reset(void)
{
	psychDialogStatus = PSYCH_STATUS_IDLE;
	psychSetResult("");
}

extern "C" int psych_ios_dialog_status(void)
{
	return psychDialogStatus;
}

extern "C" const char *psych_ios_dialog_result(void)
{
	return psychDialogResult;
}

extern "C" void psych_ios_dialog_save(const char *sourcePath)
{
	psychDialogStatus = PSYCH_STATUS_WAITING;
	psychDialogOpening = NO;
	NSString *path = [NSString stringWithUTF8String:sourcePath];
	dispatch_async(dispatch_get_main_queue(), ^{
		NSURL *url = [NSURL fileURLWithPath:path];
		UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithURL:url inMode:UIDocumentPickerModeExportToService];
		psychPresentPicker(picker);
	});
}

extern "C" void psych_ios_dialog_open(const char *cacheDir)
{
	psychDialogStatus = PSYCH_STATUS_WAITING;
	psychDialogOpening = YES;
	strncpy(psychDialogCacheDir, cacheDir ? cacheDir : "", sizeof(psychDialogCacheDir) - 1);
	dispatch_async(dispatch_get_main_queue(), ^{
		UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.item"] inMode:UIDocumentPickerModeImport];
		psychPresentPicker(picker);
	});
}

#pragma clang diagnostic pop
