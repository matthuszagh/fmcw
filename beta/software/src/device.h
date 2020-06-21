#ifndef __READ_H__
#define __READ_H__

int fmcw_open();
void fmcw_close();
int fmcw_start_acquisition(char *log_path, int sample_bits, int sweep_len);
int fmcw_read_sweep(int *arr);

#endif
