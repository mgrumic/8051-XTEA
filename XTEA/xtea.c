#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>
#include <pthread.h>

#include "rs232.h"

#define NUM_ROUNDS 32
#define MAX_STR 4096

pthread_mutex_t* mymutex = NULL;
//#define _XTEA_DEBUG
typedef enum _COM_PORT {
    COM1 = 0,
    COM2,
    COM3,
    COM4,
    COM5,
    COM6,
    COM7,
    COM8,
    COM9,
    COM10,
    COM11,
    COM12,
    COM13,
    COM14,
    COM15,
    COM16
} COM_PORT;

uint32_t key[4] = {
    0x99ab129f,
    0x4de1e6fa,
    0xbbe8b100,
    0xfa888ef3
};

static const COM_PORT CURRENT_COM_PORT = COM1;
static const uint32_t BAUD_RATE = 300;
/* take 64 bits of data in v[0] and v[1] and 128 bits of key[0] - key[3] */

void encipher(unsigned int num_rounds, uint32_t v[2], uint32_t const key[4]) {
    unsigned int i;
    uint32_t v0=v[0], v1=v[1], sum=0, delta=0x9E3779B9;
    for (i=0; i < num_rounds; i++) {
        v0 += (((v1 << 4) ^ (v1 >> 5)) + v1) ^ (sum + key[sum & 3]);
        sum += delta;
        v1 += (((v0 << 4) ^ (v0 >> 5)) + v0) ^ (sum + key[(sum>>11) & 3]);
    }
    v[0]=v0; v[1]=v1;
}

void decipher(unsigned int num_rounds, uint32_t v[2], uint32_t const key[4]) {
    unsigned int i;
    uint32_t v0=v[0], v1=v[1], delta=0x9E3779B9, sum=delta*num_rounds;
    for (i=0; i < num_rounds; i++) {
        v1 -= (((v0 << 4) ^ (v0 >> 5)) + v0) ^ (sum + key[(sum>>11) & 3]);
        sum -= delta;
        v0 -= (((v1 << 4) ^ (v1 >> 5)) + v1) ^ (sum + key[sum & 3]);
    }
    v[0]=v0; v[1]=v1;
}

void *listening( void *ptr ) {
    uint32_t dataRec[2] = {0x00000000, 0x00000000};
    uint8_t recBytes = 0;
    uint8_t buf[4096] = {0};

    int err = RS232_OpenComport(CURRENT_COM_PORT, BAUD_RATE, "8N1");
    if (err == 1) {
        RS232_CloseComport(CURRENT_COM_PORT);
        return (void*)0;
    }
    while(1) {
        int n, i;
        n = RS232_PollComport(CURRENT_COM_PORT, buf, 4096);
        if (recBytes == 0 && n) {
            pthread_mutex_lock(mymutex);
        }
        #ifdef _XTEA_DEBUG
        for (i = 0; i < n && recBytes < 8; i++) {
            fprintf(stderr, "Received byte: '0x%02X'\n", buf[i]);
        }        #else
        for (i = 0; i < n && recBytes < 8; i++) {
            ((uint8_t*)dataRec)[recBytes++] = buf[i];
        }
        if(recBytes == 8) {
        #ifdef _XTEA_DEBUG
            fprintf(stderr, "Received block: 0x%08X 0x%08X\n", dataRec[0], dataRec[1]);
        #endif
            decipher(NUM_ROUNDS, dataRec, key);
            fprintf(stderr, "Received character: '%c'\n", ((uint8_t*)dataRec)[0]);
            recBytes = 0;
            pthread_mutex_unlock(mymutex);
        }
        #endif // _XTEA_DEBUG
        Sleep(100);
    }
}
BOOL CtrlHandler( DWORD fdwCtrlType )
{
  switch( fdwCtrlType )
  {
    // Handle the CTRL-C signal.
    case CTRL_C_EVENT:
      printf( "Exiting...\n\n");
      Beep( 750, 300 );
      RS232_CloseComport(CURRENT_COM_PORT);
      pthread_mutex_destroy(mymutex);
      free(mymutex);
      exit(0);
      return( TRUE );

    // CTRL-CLOSE: confirm that the user wants to exit.
    case CTRL_CLOSE_EVENT:
      Beep( 600, 200 );
      return( TRUE );

    // Pass other signals to the next handler.
    case CTRL_BREAK_EVENT:
      Beep( 900, 200 );
      return FALSE;

    case CTRL_LOGOFF_EVENT:
      Beep( 1000, 200 );
      return FALSE;

    case CTRL_SHUTDOWN_EVENT:
      Beep( 750, 500 );
      return FALSE;

    default:
      return FALSE;
  }
}
int main() {
    pthread_t listening_thread;
    int iret1;
    uint32_t buffer[2] = {0};
    mymutex = (pthread_mutex_t*) malloc (sizeof(pthread_mutex_t));
    pthread_mutex_init(mymutex, NULL);
    iret1 = pthread_create( &listening_thread, NULL, listening, (void*)"");
    if(iret1) {
        fprintf(stderr,"Error - pthread_create() return code: %d\n",iret1);
        exit(EXIT_FAILURE);
    } else {
        fprintf(stderr,"Listening thread created... Success\n");
    }

    if(SetConsoleCtrlHandler((PHANDLER_ROUTINE)CtrlHandler, TRUE)) {
        printf( "\nThe Control Handler is installed... Success\n" );
    }

    while(1) {
        char c = fgetc(stdin);
        pthread_mutex_lock(mymutex);
        int i;
        if (c > 0x21 || c == ' ') {
            buffer[0] = (uint32_t) c;
            encipher(NUM_ROUNDS, buffer, key);
            for(i = 0; i < 8; i++) {
                RS232_SendByte(CURRENT_COM_PORT, ((uint8_t*)buffer)[i]);
                Sleep(100);
            }
            fprintf(stderr, "Sent char: %c (0x%08X%08X)\n", c, buffer[0], buffer[1]);
            buffer[0] = 0;
            buffer[1] = 0;
        }
        pthread_mutex_unlock(mymutex);
        Sleep(1000);
    }
}
