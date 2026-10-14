package mobile;

#if cpp
@:cppFileCode('
#include <signal.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <stdio.h>
#include <stdint.h>
#include <unwind.h>
#include <dlfcn.h>
#if !defined(__APPLE__)
#include <ucontext.h>
#endif

static char psychCrashPath[1024] = {0};

struct PsychBacktraceState
{
	void **current;
	void **end;
};

static _Unwind_Reason_Code psychUnwindCallback(struct _Unwind_Context *context, void *arg)
{
	PsychBacktraceState *state = (PsychBacktraceState *)arg;
	uintptr_t pc = _Unwind_GetIP(context);
	if (pc)
	{
		if (state->current == state->end) return _URC_END_OF_STACK;
		*state->current++ = (void *)pc;
	}
	return _URC_NO_REASON;
}

static void psychWriteAddress(int fd, const char *label, uintptr_t address)
{
	char buf[768];
	Dl_info dl;
	const char *lib = "?";
	const char *sym = "";
	uintptr_t offset = address;
	if (address && dladdr((void *)address, &dl))
	{
		if (dl.dli_fname) lib = dl.dli_fname;
		if (dl.dli_sname) sym = dl.dli_sname;
		offset = address - (uintptr_t)dl.dli_fbase;
	}
	int len = snprintf(buf, sizeof(buf), "%s: %s +0x%lx %s\\n", label, lib, (unsigned long)offset, sym);
	if (len > 0) write(fd, buf, len);
}

static void psychCrashHandler(int sig, siginfo_t *info, void *ucontext)
{
	int fd = open(psychCrashPath, O_WRONLY | O_CREAT | O_TRUNC, 0644);
	if (fd >= 0)
	{
		char buf[768];
		int len = snprintf(buf, sizeof(buf), "Native crash: signal %d (code %d) at address %p\\n\\n", sig, info ? info->si_code : 0, info ? info->si_addr : 0);
		if (len > 0) write(fd, buf, len);

		if (ucontext)
		{
			uintptr_t pc = 0;
			uintptr_t lr = 0;
			#if defined(__APPLE__)
			#elif defined(__aarch64__)
			pc = (uintptr_t)((ucontext_t *)ucontext)->uc_mcontext.pc;
			lr = (uintptr_t)((ucontext_t *)ucontext)->uc_mcontext.regs[30];
			#elif defined(__arm__)
			pc = (uintptr_t)((ucontext_t *)ucontext)->uc_mcontext.arm_pc;
			lr = (uintptr_t)((ucontext_t *)ucontext)->uc_mcontext.arm_lr;
			#endif
			psychWriteAddress(fd, "PC", pc);
			psychWriteAddress(fd, "LR", lr);
			write(fd, "\\n", 1);
		}

		void *frames[64];
		PsychBacktraceState state = { frames, frames + 64 };
		_Unwind_Backtrace(psychUnwindCallback, &state);
		int count = (int)(state.current - frames);
		for (int i = 0; i < count; i++)
		{
			Dl_info dl;
			const char *lib = "?";
			const char *sym = "";
			uintptr_t offset = 0;
			if (dladdr(frames[i], &dl))
			{
				if (dl.dli_fname) lib = dl.dli_fname;
				if (dl.dli_sname) sym = dl.dli_sname;
				offset = (uintptr_t)frames[i] - (uintptr_t)dl.dli_fbase;
			}
			len = snprintf(buf, sizeof(buf), "#%02d %s +0x%lx %s\\n", i, lib, (unsigned long)offset, sym);
			if (len > 0) write(fd, buf, len);
		}
		close(fd);
	}

	fd = open(psychCrashPath, O_WRONLY | O_APPEND);
	if (fd >= 0)
	{
		write(fd, "\\nHaxe stack:\\n", 13);
		close(fd);
		::Array< ::String > stack = __hxcpp_get_call_stack(false);
		fd = open(psychCrashPath, O_WRONLY | O_APPEND);
		if (fd >= 0)
		{
			for (int i = 0; i < stack->length; i++)
			{
				const char *line = stack->__get(i).utf8_str();
				if (line)
				{
					write(fd, line, strlen(line));
					write(fd, "\\n", 1);
				}
			}
			close(fd);
		}
	}

	signal(sig, SIG_DFL);
	raise(sig);
}

static void psychInstallCrashHandler(const char *path)
{
	strncpy(psychCrashPath, path, sizeof(psychCrashPath) - 1);
	struct sigaction sa;
	memset(&sa, 0, sizeof(sa));
	sa.sa_sigaction = psychCrashHandler;
	sa.sa_flags = SA_SIGINFO | SA_RESETHAND;
	sigemptyset(&sa.sa_mask);
	sigaction(SIGSEGV, &sa, NULL);
	sigaction(SIGABRT, &sa, NULL);
	sigaction(SIGBUS, &sa, NULL);
	sigaction(SIGILL, &sa, NULL);
	sigaction(SIGFPE, &sa, NULL);
}
')
#end
class NativeCrash
{
	static inline final FILE_NAME:String = 'native_crash.txt';

	public static function install()
	{
		#if cpp
		try
		{
			if (!FileSystem.exists('crash')) FileSystem.createDirectory('crash');
		}
		catch (e:Dynamic) {}
		var path:String = haxe.io.Path.addTrailingSlash(Sys.getCwd()) + 'crash/' + FILE_NAME;
		untyped __cpp__('psychInstallCrashHandler({0}.utf8_str())', path);
		#end
	}

	public static function reportPrevious()
	{
		var path:String = 'crash/' + FILE_NAME;
		try
		{
			if (!FileSystem.exists(path)) return;
			var content:String = File.getContent(path);
			var dateNow:String = Date.now().toString().replace(' ', '_').replace(':', "'");
			var savedPath:String = 'crash/PsychEngine_native_$dateNow.txt';
			File.saveContent(savedPath, content);
			FileSystem.deleteFile(path);
			lime.app.Application.current.window.alert(content + '\nSaved at: ' + savedPath, 'The game closed unexpectedly last time');
		}
		catch (e:Dynamic) {}
	}
}
