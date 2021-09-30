#ifndef __GD_BIOS__
#define __GD_BIOS__

// Defines

// GD_InitGPURead flags
#define GD_GPU_READ_PRESERVE		0
#define GD_GPU_READ_FAST			1

// GD_FOpen mode
#define	GD_FOPEN_READ				0x01
#define	GD_FOPEN_WRITE				0x02
#define	GD_FOPEN_OPEN_EXISTING		0x00
#define	GD_FOPEN_CREATE_NEW			0x04
#define	GD_FOPEN_CREATE_ALWAYS		0x08
#define	GD_FOPEN_OPEN_ALWAYS		0x10
#define	GD_FOPEN_OPEN_APPEND		0x30

// GD_FRead flags
#define GD_FREAD_CPU				0
#define GD_FREAD_GPU				1
#define GD_FREAD_GPU_ASYNC			2

// GD_FSeek flags
#define GD_FSEEK_SET				0
#define GD_FSEEK_CUR				1
#define GD_FSEEK_END				2

// GD_FInfo & GD_DRead flags
#define GD_FINFO_SHORT_NAME			0
#define GD_FINFO_LONG_NAME			1

// GD_Reset flags
#define GD_RESET_NORMAL				0
#define GD_RESET_MENU				1
#define GD_RESET_DEBUG				2

// Type definitions

typedef unsigned char u8;
typedef unsigned short u16;
typedef unsigned long u32;
typedef unsigned long long u64;
typedef signed char s8;
typedef signed short s16;
typedef signed long s32;
typedef signed long long s64;

// Struct definitions

// Struct for GD_FINFO_SHORT_NAME
typedef struct
{
	u32		nSize;				// size
	u16		nDate;				// modified date, 5/6/5 bits, for hour/minutes/doubleseconds
	u16		nTime;				// modified time, 7/4/5 bits, for year-since-1980/month/day
	u8		nAttrib;			// file attributes
	char	szAltName[13];		// short filename
} CGDFileInfoShort;

// Struct for GD_FINFO_LONG_NAME
typedef struct
{
	u32		nSize;				// size
	u16		nDate;				// modified date, 5/6/5 bits, for hour/minutes/doubleseconds
	u16		nTime;				// modified time, 7/4/5 bits, for year-since-1980/month/day
	u8		nAttrib;			// file attributes
	char	szAltName[13];		// short filename
	char	szLongName[256];	// long filename
} CGDFileInfoLong;

// Function definitions

u16 GD_Install(void *buffer);
void GD_InitGPURead(void *buffer, u16 flags);
u16 GD_BIOSVersion();
u32 GD_HWVersion();
void GD_ROMWriteEnable(u16 flags);
void ROMSetPage(u16 page, u16 bank);
void ROMSetPages(u32 banks);
u16 GD_GetCartSerial(void *buffer);
u16 GD_GetCardSerial(void *buffer);
u16 GD_FOpen(const char *filename, u16 mode);
u16 GD_FRead(u16 handle, void *buffer, u32 size, u16 flags);
u16 GD_FWrite(u16 handle, void *buffer, u32 size);
u16 GD_FSeek(u16 handle, u16 flags, s32 offset);
u16 GD_FClose(u16 handle);
u32 GD_FTell(u16 handle);
u32 GD_FSize(u16 handle);
u32 GD_FAsyncPos();
void GD_FAsyncWait();
u16 GD_FAsyncActive();
u16 GD_FInfo(const char *filename, void *buffer, u16 flags);
u16 GD_DOpen(const char *filename);
u16 GD_DRead(u16 handle, void *buffer, u16 flags);
u16 GD_DClose(u16 handle);
u16 GD_CardIn();
u16 GD_Reset(u16 flags);
u16 GD_SetLED(u16 flags);
void GD_DebugString(const char *string);
const char *GD_BINtoASCII(char *ascii, void *bin);

#endif // __GD_BIOS__