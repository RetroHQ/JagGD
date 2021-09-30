					.68000

;|==============================================================================


GD_Init				.equ	1
GD_InitGPURead		.equ	2
GD_BIOSVersion		.equ	3
GD_ROMWriteEnable	.equ	4
GD_ROMSetPage		.equ	5
GD_ROMSetPages		.equ	6
GD_GetCartSerial	.equ	7
GD_GetCardSerial	.equ	8
GD_CardIn			.equ	9
GD_FileOpen			.equ	10
GD_FileClose		.equ	11
GD_FileSeek			.equ	12
GD_FileRead			.equ	13
GD_FileWrite		.equ	14
GD_FileTell			.equ	15
GD_FileSize			.equ	16
GD_FileAsyncPos		.equ	17
GD_FileAsyncWait	.equ	18
GD_FileAsyncActive	.equ	19
GD_FileInfo			.equ	20
GD_DirOpen			.equ	21
GD_DirRead			.equ	22
GD_DirClose			.equ	23
GD_Reset			.equ	24
GD_SetLED			.equ	25
GD_DebugString		.equ	26

MINVERSION			.equ	$100

;|==============================================================================

ASIC_SPI_STATUS_HAVE_DATA_BIT			.equ	3

ASIC_SPI_STATUS_PACKET_START			.equ	1<<4
ASIC_SPI_STATUS_SLAVE_SELECT			.equ	1<<0
ASIC_SPI_STATUS_LATCH_FULL				.equ	1<<5

ASIC_SPI_STATUS							.equ	$F16002
ASIC_SPI_DATA							.equ	$F16004
ASIC_SPI_DATA_BYTE						.equ	$F16005

;|==============================================================================

.macro				GDFunc
					// \1 : function number
					move.l		a6,-(sp)
					tst.l		GDB_Base
					beq			NoFunc
					move.l		GDB_Base,a6					; base of gd bios
					cmp.w		#\1,2(a6)
					blt			NoFunc
					jsr			\1*4(a6)					; call GD BIOS function
					move.l		(sp)+,a6
					rts
.endm

;|==============================================================================
					.data
;|==============================================================================

GDB_Base:			dc.l	0

;|==============================================================================
					.text
;|==============================================================================

NoFunc:				moveq		#-1,d0
					move.l		(sp)+,a6
					rts

;|==============================================================================
;| u32 GD_HWVersion()
;|------------------------------------------------------------------------------
;| Get the GD hardware, nn.nn BCD format, high word FIRMWARE, low word ASIC
;|==============================================================================

					.globl		_GD_HWVersion
_GD_HWVersion:		move.w		#ASIC_SPI_STATUS_PACKET_START,ASIC_SPI_STATUS	; request a packet start
					bsr			GDWaitData										; wait for GD to acknowledge
					move.w		#12,d0											; hw version
					bsr			GDExchangeWord									; send command word

					moveq		#0,d0											; command data size word
					bsr			GDExchangeWord									; send 0 for param size
					move.w		#ASIC_SPI_STATUS_PACKET_START,ASIC_SPI_STATUS	; we're done, process it GD!

					; recieve the size of the block
					bsr			GDWaitData										; wait for data to be available
					bsr			GDExchangeWord									; read word
					swap		d0
					bsr			GDExchangeWord									; read word

					clr.w		ASIC_SPI_STATUS									; end of packet

					move.w		#500,d0
.pause:				dbra		d0,.pause										; pause to let the micro finish up
					rts

;|==============================================================================
;| u16 GD_Install(void *buffer)
;|------------------------------------------------------------------------------
;| Install the GD BIOS to the given address. 0 success, -ve failure
;|==============================================================================

					.globl		_GD_Install
_GD_Install:		
					; first make sure the firmware is new enough for the GDBIOS
					bsr			_GD_HWVersion									; get FW & ASIC version
					swap		d0												; want firmware
					cmp.w		#$111,d0										; version 1.11 is the first with GDBIOS
					bge.s		.install										; >=, install!

					clr.l		GDB_Base
					moveq		#-1,d0											; failed
					rts

.install:			move.l		4(sp),a0										; buffer to write to
					
					; drain SPI latch incase of FIFO DMA termiation
.waitLatch:			move.w		ASIC_SPI_STATUS,d0
					and.w		#ASIC_SPI_STATUS_LATCH_FULL,d0
					beq.s		.noLatch
					tst.w		ASIC_SPI_DATA									; read result
					bra.s		.waitLatch
.noLatch:
					; request GDBIOS block
					move.w		#ASIC_SPI_STATUS_PACKET_START,ASIC_SPI_STATUS	; request a packet start
					bsr			GDWaitData										; wait for GD to acknowledge
					move.w		#$80,d0											; install command
					bsr			GDExchangeWord									; send command word

					moveq		#0,d0											; command data size word
					bsr			GDExchangeWord									; send 0 for param size
					move.w		#ASIC_SPI_STATUS_PACKET_START,ASIC_SPI_STATUS	; we're done, process it GD!

					; recieve the size of the block
					bsr			GDWaitData										; wait for data to be available
					bsr			GDExchangeWord									; read word, this is the size of the data
					move.w		#ASIC_SPI_STATUS_PACKET_START,ASIC_SPI_STATUS	; we're done with this block GD!

					; recieve the block of data
					move.w		d0,d1											; data block size in d1
					move.l		a0,GDB_Base										; base of the GD BIOS

.nextBlock:			bsr			GDWaitData										; wait for data to be ready

					move.w		d1,d0											; bytes to read
					cmp.w		#512,d1											; max of 512 per packet
					ble.s		.sizeOk
					move.w		#512,d0
.sizeOk:			sub.w		d0,d1											; subtract what we've read
					
					subq.w		#1,d0											; dbra adjust

.readBytes:			move.w		d0,ASIC_SPI_DATA								; send byte
.waitBusy:			tst.w		ASIC_SPI_STATUS									; wait until not busy
					bmi.s		.waitBusy
					move.b		ASIC_SPI_DATA_BYTE,(a0)+						; read byte
					dbra		d0,.readBytes

					move.w		#ASIC_SPI_STATUS_PACKET_START,ASIC_SPI_STATUS	; we're done with this block GD!

					tst.w		d1												; are we done?
					bne.s		.nextBlock										; no, read more blocks

					; see if the BIOS we have is new enough
					moveq		#0,d0											; return 0
					move.l		GDB_Base,a0
					cmp.w		#MINVERSION,(a0)
					bge.s		.verOk
					subq.w		#1,d0

.verOk:				clr.w		ASIC_SPI_STATUS									; end of packet
					GDFunc		GD_Init											; do any specific initialistaion

;|------------------------------------------------------------------------------

GDWaitData:
.waitData:			move.w		ASIC_SPI_STATUS,d0
					btst.l		#ASIC_SPI_STATUS_HAVE_DATA_BIT,d0
					bne.s		.waitData										; wait for data available bit to be low

					; lower slave select to ack packet start, keep packet flag high
					move.w		#ASIC_SPI_STATUS_PACKET_START|ASIC_SPI_STATUS_SLAVE_SELECT,ASIC_SPI_STATUS

.waitAck:			move.w		ASIC_SPI_STATUS,d0
					btst.l		#ASIC_SPI_STATUS_HAVE_DATA_BIT,d0
					beq.s		.waitAck										; wait for data available bit to be high (slave ack)
					rts

;|------------------------------------------------------------------------------

GDExchangeWord:		move.w		d0,ASIC_SPI_DATA								; send byte
.waitBusy:			tst.w		ASIC_SPI_STATUS									; wait until not busy
					bmi.s		.waitBusy
					move.b		ASIC_SPI_DATA_BYTE,d0							; read byte
					ror.w		#8,d0											; shift

					move.w		d0,ASIC_SPI_DATA								; send byte
.waitBusy2:			tst.w		ASIC_SPI_STATUS									; wait until not busy
					bmi.s		.waitBusy2
					move.b		ASIC_SPI_DATA_BYTE,d0							; read byte
					rts

;|==============================================================================
;| const char *GD_BINtoASCII(char *ascii, void *bin)
;|------------------------------------------------------------------------------
;| Convert 16 byte binary serial number into 26 byte ASCII
;|==============================================================================

ASCII:				dc.b		"KPLGQ0416FCMXZ8RV9SB325HYNTADJ7W"

					.globl		_GD_BINtoASCII
_GD_BINtoASCII:		move.l		4(sp),a1										; ascii
					move.l		8(sp),a0										; bin

					movem.l		d2-d3/a2,-(sp)
					
					lea			ASCII,a2										; conversion table

					moveq		#0,d0
					move.b		(a0)+,d0										; fill buffer
					lsl.w		#8,d0
					move.b		(a0)+,d0
					
					moveq		#16,d2											; bits available
					moveq		#0,d3											; character count out

.bitsLeft:			lsl.l		#5,d0											; 5 bits per char
					swap		d0												; just char bits
					add.w		d3,d0											; rotate encoding
					and.w		#31,d0											; clip to 31 chars
					move.b		(a2,d0.w),(a1)+									; ASCII byte
					clr.w		d0
					swap		d0

					addq		#1,d3											; one more char encoded
					cmp.w		#25,d3											; are we done?
					bgt.s		.done
					beq.s		.bitsLeft										; the last 2 bits are 0 (actually encodes 130 bits)
		
					subq		#5,d2											; 5 less bits
					cmp.w		#5,d2											; must have at least 5 bits to encode more
					bge.s		.bitsLeft

					addq		#8,d2											; one more byte available

					moveq		#0,d1
					move.b		(a0)+,d1										; get extra byte
					ror.w		d2,d1											; move byte into correct position
					or.w		d1,d0											; or into buffer
					bra.s		.bitsLeft

.done:				clr.b		(a1)+											; add terminating character
					movem.l		(sp)+,d2-d3/a2
					move.l		4(sp),d0										; return the ascii buffer address
					rts


;|==============================================================================
;| void GD_InitGPURead(void *buffer, u16 flags)
;|------------------------------------------------------------------------------
;| Install GPU read code in given GPU RAM loation
;|==============================================================================

					.globl		_GD_InitGPURead
_GD_InitGPURead:	move.l		4(sp),a0										; buffer
					move.w		10(sp),d0										; flags
					GDFunc		GD_InitGPURead
					
;|==============================================================================
;| u16 GD_BIOSVersion()
;|------------------------------------------------------------------------------
;| Get the GD BIOS version, nn.nn BCD format
;|==============================================================================

					.globl		_GD_BIOSVersion
_GD_BIOSVersion:	GDFunc		GD_BIOSVersion

;|==============================================================================
;| u16 GD_GetCartSerial(void *buffer)
;|------------------------------------------------------------------------------
;| Get the 16 byte unique serial number for the GD cart, can be converted to
;| the ASCII version seen in the booter by using GD_BINtoASCII
;|
;| Returns:
;| 0 - success
;| !0 - failure
;|==============================================================================

					.globl		_GD_GetCartSerial
_GD_GetCartSerial:	move.l		4(sp),a0					; output buffer
					GDFunc		GD_GetCartSerial
					
;|==============================================================================
;| u16 GD_GetCardSerial(void *buffer)
;|------------------------------------------------------------------------------
;| Get the 16 byte unique serial number for the inserted memory card
;|
;| Returns:
;| 0 - success
;| !0 - failure
;|==============================================================================

					.globl		_GD_GetCardSerial
_GD_GetCardSerial:	move.l		4(sp),a0					; output buffer
					GDFunc		GD_GetCardSerial

;|==============================================================================
;| u16 GD_FOpen(const char *filename, u16 mode)
;|------------------------------------------------------------------------------
;| Open a file from the memory card
;|
;| Returns:
;| >=0 - file handle
;| <0 - failure
;|==============================================================================

					.globl		_GD_FOpen
_GD_FOpen:			move.l		4(sp),a0					; filename pointer
					move.w		10(sp),d0					; mode
					GDFunc		GD_FileOpen

;|==============================================================================
;| u16 GD_FRead(u16 handle, void *buffer, u32 size, u16 flags)
;|------------------------------------------------------------------------------
;| Read given number of bytes from the specified file
;|
;| Returns:
;| 0 - success
;| <0 - failure
;|==============================================================================

					.globl		_GD_FRead
_GD_FRead:			move.w		18(sp),d0					; flags
					swap		d0
					move.w		6(sp),d0					; file handle
					move.l		8(sp),a0					; buffer pointer
					move.l		12(sp),d1					; bytes to read
					GDFunc		GD_FileRead

;|==============================================================================
;| u16 GD_FWrite(u16 handle, void *buffer, u32 size)
;|------------------------------------------------------------------------------
;| Write given number of bytes from the specified file
;|
;| Returns:
;| 0 - success
;| <0 - failure
;|==============================================================================

					.globl		_GD_FWrite
_GD_FWrite:			moveq		#0,d0
					move.w		6(sp),d0					; file handle
					move.l		8(sp),a0					; buffer pointer
					move.l		12(sp),d1					; bytes to write
					GDFunc		GD_FileWrite

;|==============================================================================
;| u16 GD_FSeek(u16 handle, u16 flags, s32 offset)
;|------------------------------------------------------------------------------
;| Seek to the given position in the file
;|
;| Returns:
;| 0 - success
;| <0 - failure
;|==============================================================================

					.globl		_GD_FSeek
_GD_FSeek:			move.w		10(sp),d0					; flags
					swap		d0
					move.w		6(sp),d0					; file handle
					move.l		12(sp),d1					; offset
					GDFunc		GD_FileSeek

;|==============================================================================
;| u16 GD_FClose(u16 handle)
;|------------------------------------------------------------------------------
;| Close the given file handle
;|
;| Returns:
;| 0 - success
;| <0 - failure
;|==============================================================================

					.globl		_GD_FClose
_GD_FClose:			move.w		6(sp),d0					; file handle
					GDFunc		GD_FileClose

;|==============================================================================
;| u32 GD_FTell(u16 handle)
;|------------------------------------------------------------------------------
;| Get position in current file
;|
;| Returns:
;| $ffffffff - failure
;| !$ffffffff - current offset in file
;|==============================================================================

					.globl		_GD_FTell
_GD_FTell:			move.w		6(sp),d0					; file handle
					GDFunc		GD_FileTell

;|==============================================================================
;| u32 GD_FSize(u16 handle)
;|------------------------------------------------------------------------------
;| Get size of open file
;|
;| Returns:
;| $ffffffff - failure
;| !$ffffffff - size
;|==============================================================================

					.globl		_GD_FSize
_GD_FSize:			move.w		6(sp),d0					; file handle
					GDFunc		GD_FileSize

;|==============================================================================
;| u32 GD_FAsyncPos()
;|------------------------------------------------------------------------------
;| Get current async GPU read position
;|==============================================================================

					.globl		_GD_FAsyncPos
_GD_FAsyncPos:		GDFunc		GD_FileAsyncPos

;|==============================================================================
;| void GD_FAsyncWait()
;|------------------------------------------------------------------------------
;| Wait for async read operation to complete
;|==============================================================================

					.globl		_GD_FAsyncWait
_GD_FAsyncWait:		GDFunc		GD_FileAsyncWait

;|==============================================================================
;| u16 GD_FAsyncActive()
;|------------------------------------------------------------------------------
;| Return if async read is in progress
;|==============================================================================

					.globl		_GD_FAsyncActive
_GD_FAsyncActive:	GDFunc		GD_FileAsyncActive

;|==============================================================================
;| u16 GD_FInfo(const char *filename, void *buffer, u16 flags)
;|------------------------------------------------------------------------------
;| Get info about given filename, returns either CGDFileInfoShort or
;| CGDFileInfoLong depending on flag.
;|
;| Returns:
;| >=0 - file handle
;| <0 - failure
;|==============================================================================

					.globl		_GD_FInfo
_GD_FInfo:			move.l		4(sp),a0					; filename pointer
					move.l		8(sp),a1					; info buffer pointer
					move.w		14(sp),d0					; flags (bit 0, set to include long filename)
					GDFunc		GD_FileInfo

;|==============================================================================
;| u16 GD_DOpen(const char *filename)
;|------------------------------------------------------------------------------
;| Open a directory from the memory card
;|
;| Returns:
;| >=0 - file handle
;| <0 - failure
;|==============================================================================

					.globl		_GD_DOpen
_GD_DOpen:			move.l		4(sp),a0					; filename pointer
					GDFunc		GD_DirOpen

;|==============================================================================
;| u16 GD_DRead(u16 handle, void *buffer, u16 flags)
;|------------------------------------------------------------------------------
;| Get next file entry from the directory, returns either CGDFileInfoShort or
;| CGDFileInfoLong depending on flag.
;|
;| Returns:
;| >=0 - success
;| <0 - failure
;|==============================================================================

					.globl		_GD_DRead
_GD_DRead:			move.w		14(sp),d0					; flags (bit 0, set to include long filename)
					swap		d0
					move.w		6(sp),d0					; handle
					move.l		8(sp),a0					; info buffer pointer
					GDFunc		GD_DirRead

;|==============================================================================
;| u16 GD_DClose(u16 handle)
;|------------------------------------------------------------------------------
;| Close the given directory handle
;|
;| Returns:
;| 0 - success
;| <0 - failure
;|==============================================================================

					.globl		_GD_DClose
_GD_DClose:			move.w		6(sp),d0					; file handle
					GDFunc		GD_DirClose

;|==============================================================================
;| u16 GD_CardIn()
;|------------------------------------------------------------------------------
;| Return if the memory card is inserted
;|
;| Returns:
;| 0 - no
;| 1 - yes
;|==============================================================================

					.globl		_GD_CardIn
_GD_CardIn:			GDFunc		GD_CardIn

;|==============================================================================
;| u16 GD_Reset(u16 flags)
;|------------------------------------------------------------------------------
;| Reset the jaguar
;|==============================================================================

					.globl		_GD_Reset
_GD_Reset:			move.w		6(sp),d0					; flags
					GDFunc		GD_Reset

;|==============================================================================
;| u16 GD_SetLED(u16 flags)
;|------------------------------------------------------------------------------
;| Set LED state
;|==============================================================================

					.globl		_GD_SetLED
_GD_SetLED:			move.w		6(sp),d0					; flags
					GDFunc		GD_SetLED

;|==============================================================================
;| void GD_DebugString(const char *string)
;|------------------------------------------------------------------------------
;| Output given string to the virtual USB COM port
;|==============================================================================

					.globl		_GD_DebugString
_GD_DebugString:	move.l		4(sp),a0					; string
					GDFunc		GD_DebugString

;|==============================================================================
;| void GD_ROMWriteEnable(u16 flags)
;|------------------------------------------------------------------------------
;| Enable or disable write access to ROM area
;|==============================================================================

					.globl		_GD_ROMWriteEnable
_GD_ROMWriteEnable:	move.w		6(sp),d0					; flags
					GDFunc		GD_ROMWriteEnable

;|==============================================================================
;| void ROMSetPage(u16 page, u16 bank)
;|------------------------------------------------------------------------------
;| Set bank for single page.
;|
;| Page 0 : $8xxxxx
;|		1 : $9xxxxx
;|		2 : $axxxxx
;|		3 : $bxxxxx
;|		4 : $cxxxxx
;|		5 : $dxxxxx
;|
;| Bank 0-15 is 1MB pages of the onboard 16MB SDRAM
;|==============================================================================

					.globl		_GD_ROMSetPage
_GD_ROMSetPage:		move.w		6(sp),d0					; page
					swap		d0
					move.w		10(sp),d0					; bank
					GDFunc		GD_ROMSetPage

;|==============================================================================
;| void ROMSetPages(u32 banks)
;|------------------------------------------------------------------------------
;| Set all SDRAM banks at once, one per nibble.
;| Lowest significant nibble is page 0, upto nibble 5. Data above is ignored.
;|==============================================================================

					.globl		_GD_ROMSetPages
_GD_ROMSetPages:	move.l		4(sp),d0					; pages
					GDFunc		GD_ROMSetPages
