cdef extern from "src/device.h":
    bint fmcw_open()
    void fmcw_close()
    bint fmcw_start_acquisition(char *log_path, int sample_bits, int sweep_len, bint fft)
    int fmcw_read_sweep(int *arr)
    bint fmcw_add_write(int val, int nbytes)
    bint fmcw_write_pending()
