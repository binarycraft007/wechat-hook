#include <windows.h>
#include <string>
using namespace std;

struct WxString {
	wchar_t* buffer;
	int size;
	int capacity;
	char padding[8];
};

struct SendTextMessageOptions {
	const wchar_t *id;
	const wchar_t *msg;
	DWORD addr;
};

extern "C" {
	void sendTextMessage(SendTextMessageOptions options);
}

void sendTextMessage(SendTextMessageOptions options) {
	wstring wsWxId = options.id;
	wstring wsTextMsg = options.msg;

	WxString wxWxId = { 0 };
	wxWxId.buffer = (wchar_t*)wsWxId.c_str();
	wxWxId.size = wsWxId.size();
	wxWxId.capacity = wsWxId.capacity();

	WxString wxTextMsg = { 0 };
	wxTextMsg.buffer = (wchar_t*)wsTextMsg.c_str();
	wxTextMsg.size = wsTextMsg.size();
	wxTextMsg.capacity = wsTextMsg.capacity();

	WxString wxNULL = { 0 };

	char buffer[0x738] = { 0 };

	__asm {
		push 0x1;

		lea eax, wxNULL;
		push eax;

		lea ebx, wxTextMsg;
		push ebx;

		lea edx, wxWxId;		
		lea ecx, buffer;

		call options.addr;

		add esp, 0xC;
	}
}
