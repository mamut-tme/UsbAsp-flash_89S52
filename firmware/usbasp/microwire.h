/*
 * microwire.h - part of USBasp
 *
 * Autor..........: Alexander 'nofeletru'
 * Description....: Provides functions for communication/programming
 *                  over microwire interface
 * Licence........: unknown GPLv2?

 */

#ifndef __microwire_h_included__
#define	__microwire_h_included__
//Functions for sw microwire interface
void mwStart();

void mwSendData(unsigned int data,unsigned char n);

unsigned char mwReadByte();

void mwEnd();

uchar mwBusy();
#endif /* __microwire_h_included__ */
