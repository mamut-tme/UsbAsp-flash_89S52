# UsbAsp-flash_89S52
This is a firmware for the UsbAsp programmer based on 
- UsbAsp-flash (https://github.com/nofeletru/UsbAsp-flash) containing the possibility to read/write I2C, SPI and Microwire memories and possibly other devices. An additional change I have found is the possibility to use 3 MHz SCK clock for programming AVRs, not supported by AVRDUDE.
- usbasp.2012-07-20_89s52 by Miles McCoo (https://blog.mmccoo.com/2012/07/21/using-usbasp-and-avrdude-to-program-89s52/) containing the possibility to write AT89S51 and AT89S52 8051 MCUs. 

Please be aware that this is really a hack. The firmware imitates that
the targed MCU is a AT89S51/AT89S52. However, some usbasp commands could
be added to ensure real communication, but then a special application for
the PC should be written (or avrdude patched).

20200803:
- both firmwares merged with success. Seems to work a bit slower than UsbAsp-flash when reading whole memory from ATmega328p using AVRDUDE with -B 0.3 (like 0.1s slower, but this is from memory)
- added patch for avrdude 6.3 using the 3 MHz SCK. I have no target to test the 6 MHz SCK - sorry.
- review of S5x changes for potential optimization in progress.

20200804:
- working paged read for S5x, write probably working (only target died :( )
- added full avrdude source code. added displaying of automaticly set SCK speed in avrdude
- added new capabilities byte [2]
- added test request 100 to debug ISP commands.
- removed avrisp firmware - no job here.
- added NeoProgrammer binary - works with this firmware