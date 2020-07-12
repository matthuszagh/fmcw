#ifndef __READ_H__
#define __READ_H__

#include <stdint.h>

int fmcw_open();
void fmcw_close();
int fmcw_start_acquisition(char *log_path, int sample_bits, int sweep_len, int fft);
int fmcw_read_sweep(int *arr);
int fmcw_add_write(uint32_t val, int nbytes);
int fmcw_write_pending();

#endif
