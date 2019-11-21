#include "bitmanip.h"
#include <bits/stdint-uintn.h>
#include <ftdi.h>
#include <limits.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define PACKET_LEN 8
#define FFT_LEN 1024
/* Average samples over this number of reads. */
#define AVG_INDEX 30000

/* Valid messages to send radar. */
#define IDLE 0
#define FFT 1
#define WINDOW 2
#define FIR 3
#define RAW 4

/**
 * Find the first packet with correct header and tail sequences.
 */
int seek_valid(uint8_t *buffer, int length, int *pos)
{
	while (*pos + 7 < length) {
		if (buffer[*pos] == 128 && (buffer[*pos + 7] & '\x0f') == 0) {
			return 0;
		}
		++*pos;
	}

	return -1;
}

/**
 * Read and return an 8 byte word from @buffer at position @pos. It's
 * up to the caller to ensure reads do not extend past the end of
 * @buffer.
 */
uint64_t read64(uint8_t *buffer, int *pos)
{
	int i;
	uint64_t res;

	i = 0;
	res = 0;
	while (i < 8) {
		add_byte_to_word(&res, 8 * (7 - i), buffer[*pos]);
		++i;
		++*pos;
	}

	return res;
}

unsigned int bitrev(unsigned int v, int num_bits)
{
	unsigned int r;
	int s;

	r = v;
	s = sizeof(v) * CHAR_BIT - 1;

	for (v >>= 1; v; v >>= 1) {
		r <<= 1;
		r |= v & 1;
		--s;
	}
	r <<= s;
	r >>= sizeof(v) * CHAR_BIT - num_bits;
	return r;
}

/**
 * Ensure data is in a valid state. This means that it contains the
 * appropriate header and stop sequence and has the correct parity
 * bit.
 */
int dvalid(uint64_t val)
{
	uint8_t header;
	uint8_t tail;

	header = val >> (8 * (PACKET_LEN - 1));
	tail = (val & '\xf');

	return header == 128 && tail == 0;
}

static int exit_requested = 0;
static uint32_t start = 0;
static uint32_t offset = 0;
static int fn = 0;
static uint64_t last_val;
static int second_val;
static int last_fft;
static unsigned int last_ctr;
static int last_tx_re;
static int coverage;
/* keep track of the number of times a value is found for each bit
 * position. This is used to periodically divide the accumulator. */
static int idx_ctr[FFT_LEN];
static int avg_ctr = 0;
/* Accumulate values and average periodically. This is used as a
 * solution for dropped values. */
static int64_t accum[FFT_LEN];
/* raw samples */
static int64_t raw_a[FFT_LEN];
static int64_t raw_b[FFT_LEN];
/* fir output */
static int64_t fir_a[FFT_LEN];
static int64_t fir_b[FFT_LEN];
/* kaiser window output */
static int64_t window[FFT_LEN];
static unsigned char op_state = IDLE;

void write_fft(FILE *f)
{
	int i;
	for (i = 0; i < FFT_LEN / 2; ++i) {
		if (idx_ctr[i] != 0) {
			accum[i] /= idx_ctr[i];
		} else {
			accum[i] = 0;
		}

		fprintf(f, "%8d %8u\n", accum[i], i);
		accum[i] = 0;
		idx_ctr[i] = 0;
	}
}

void write_raw(FILE *f)
{
	int i;
	for (i = 0; i < FFT_LEN; ++i) {
		if (idx_ctr[i] != 0) {
			raw_a[i] /= idx_ctr[i];
			raw_b[i] /= idx_ctr[i];
		} else {
			raw_a[i] = 0;
			raw_b[i] = 0;
		}

		fprintf(f, "%6d %6d %6u\n", raw_a[i], raw_b[i], i);
		raw_a[i] = 0;
		raw_b[i] = 0;
		idx_ctr[i] = 0;
	}
}

void write_window(FILE *f)
{
	int i;
	for (i = 0; i < FFT_LEN; ++i) {
		if (idx_ctr[i] != 0) {
			window[i] /= idx_ctr[i];
		} else {
			window[i] = 0;
		}

		fprintf(f, "%6d %6u\n", window[i], i);
		window[i] = 0;
		idx_ctr[i] = 0;
	}
}

void write_fir(FILE *f)
{
	int i;
	for (i = 0; i < FFT_LEN; ++i) {
		if (idx_ctr[i] != 0) {
			fir_a[i] /= idx_ctr[i];
			fir_b[i] /= idx_ctr[i];
		} else {
			fir_a[i] = 0;
			fir_b[i] = 0;
		}

		fprintf(f, "%6d %6u\n", window[i], i);
		fir_a[i] = 0;
		fir_b[i] = 0;
		idx_ctr[i] = 0;
	}
}

void flush_data(int fn)
{
	FILE *fout;
	char fout_name[32];

	sprintf(fout_name, "data/%05d.dec", fn);
	fout = fopen(fout_name, "w");
	if (!fout) {
		fputs("Failed to open output file. "
		      "Exiting...",
		      stderr);
		exit(EXIT_FAILURE);
	}
	if (op_state == FFT) {
		write_fft(fout);
	} else if (op_state == WINDOW) {
		write_window(fout);
	} else if (op_state == FIR) {
		write_fir(fout);
	} else if (op_state == RAW) {
		write_raw(fout);
	}
	fclose(fout);
}

static void proc_fft(uint64_t rdval)
{
	int fft;
	int fft_res;
	unsigned int ctr;
	int tx_re;

	fft = subw_val(rdval, 4, 25, 1);
	ctr = subw_val(rdval, 29, 10, 0);
	tx_re = subw_val(rdval, 39, 1, 0);

	if (last_ctr == ctr && last_tx_re != tx_re) {
		fft_res = (int)sqrt(pow(fft, 2) + pow(last_fft, 2));
		accum[ctr] += fft_res;
		++idx_ctr[ctr];
		if (avg_ctr == AVG_INDEX) {
			avg_ctr = 0;
			flush_data(fn);
			++fn;
		} else {
			++avg_ctr;
		}
	}
	last_fft = fft;
	last_ctr = ctr;
	last_tx_re = tx_re;
}

static void proc_window(uint64_t rdval)
{
	int win;
	unsigned int ctr;

	win = subw_val(rdval, 4, 14, 1);
	ctr = subw_val(rdval, 18, 10, 0);

	++idx_ctr[ctr];
	window[ctr] += win;
	if (avg_ctr == AVG_INDEX) {
		avg_ctr = 0;
		flush_data(fn);
		++fn;
	} else {
		++avg_ctr;
	}
}

static void proc_raw(uint64_t rdval)
{
	int chan_a;
	int chan_b;
	unsigned int ctr;

	chan_a = subw_val(rdval, 4, 12, 1);
	chan_b = subw_val(rdval, 16, 12, 1);
	ctr = subw_val(rdval, 28, 10, 0);

	++idx_ctr[ctr];
	raw_a[ctr] += chan_a;
	raw_b[ctr] += chan_b;
	if (avg_ctr == AVG_INDEX) {
		avg_ctr = 0;
		flush_data(fn);
		++fn;
	} else {
		++avg_ctr;
	}
}

static void proc_fir(uint64_t rdval)
{
	int chan_a;
	int chan_b;
	unsigned int ctr;

	chan_a = subw_val(rdval, 4, 14, 1);
	chan_b = subw_val(rdval, 18, 14, 1);
	ctr = subw_val(rdval, 32, 10, 0);

	++idx_ctr[ctr];
	fir_a[ctr] += chan_a;
	fir_b[ctr] += chan_b;
	if (avg_ctr == AVG_INDEX) {
		avg_ctr = 0;
		flush_data(fn);
		++fn;
	} else {
		++avg_ctr;
	}
}

/**
 * TODO
 */
static int read_callback(uint8_t *buffer, int length, FTDIProgressInfo *progress, void *userdata)
{
	int pos;
	uint64_t rdval;

	pos = 0;
	seek_valid(buffer, length, &pos);
	while (pos + 7 <= length) {
		rdval = read64(buffer, &pos);

		if (!dvalid(rdval)) {
			second_val = 0;
			seek_valid(buffer, length, &pos);
		} else {
			if (second_val) {
				if (rdval == last_val) {
					if (op_state == FFT) {
						proc_fft(rdval);
					} else if (op_state == WINDOW) {
						proc_window(rdval);
					} else if (op_state == FIR) {
						proc_fir(rdval);
					} else if (op_state == RAW) {
						proc_raw(rdval);
					}
					second_val = 0;
				}
			} else {
				second_val = 1;
			}
			last_val = rdval;
		}
	}

	return exit_requested ? 1 : 0;
}

int main(int argc, char **argv)
{
	struct ftdi_context *ftdi;
	int ftdi_err;
	int opt;
	int dist;
	char interm[10];
	FILE *fmode;

	memset(interm, 0, 10);
	dist = 1;
	while ((opt = getopt(argc, argv, "ha:i:")) != -1) {
		switch (opt) {
		case 'a':
			if (strcmp(optarg, "dist") != 0) {
				dist = 0;
			} else {
				dist = 1;
			}
			break;
		case 'i':
			*interm = *optarg;
			break;
		case 'h':
			printf("Usage: %s [OPTION]\n\n"
			       "  -h  display this message\n"
			       "  -a  specify radar action\n"
			       "      values: dist or angle (defaults to dist)\n"
			       "  -i  get data from an intermediary step\n"
			       "      values: raw, fir, window, or fft (defaults to fft)\n"
			       "      fft retrieves fully processed output\n\n",
			       argv[0]);
			return EXIT_SUCCESS;
			break;
		default:
			break;
		}
	}

	if (!interm[0]) {
		strcpy(interm, "fft");
	}

	if ((ftdi = ftdi_new()) == 0) {
		fprintf(stderr, "ftdi_new failed\n");
		return EXIT_FAILURE;
	}

	if (ftdi_set_interface(ftdi, INTERFACE_A) < 0) {
		fprintf(stderr, "ftdi_set_interface failed\n");
		ftdi_free(ftdi);
		return EXIT_FAILURE;
	}

	if (ftdi_usb_open_desc(ftdi, 0x0403, 0x6010, NULL, NULL) < 0) {
		fprintf(stderr, "Can't open ftdi device: %s\n", ftdi_get_error_string(ftdi));
		ftdi_free(ftdi);
		return EXIT_FAILURE;
	}

	/* When the host PC requests a read, the FTDI device will only
	 * send data if the number of bytes requested is available. If
	 * not, the FTDI waits until the bytes are available before
	 * sending, or until the latency timer (1-255ms) has
	 * expired. */
	if (ftdi_set_latency_timer(ftdi, 2)) {
		fprintf(stderr, "Can't set latency, Error %s\n", ftdi_get_error_string(ftdi));
		ftdi_usb_close(ftdi);
		ftdi_free(ftdi);
		return EXIT_FAILURE;
	}

	/* Configures FT2232H for synchronous FIFO mode. */
	if (ftdi_set_bitmode(ftdi, 0xff, BITMODE_SYNCFF) < 0) {
		fprintf(stderr, "Can't set synchronous fifo mode, Error %s\n",
			ftdi_get_error_string(ftdi));
		ftdi_usb_close(ftdi);
		ftdi_free(ftdi);
		return EXIT_FAILURE;
	}

	/* Unfortunately this is maxed out on linux as 16KB even
	 * though FTDI recommends setting it to 64KB. */
	ftdi_read_data_set_chunksize(ftdi, 16384);

	if (ftdi_setflowctrl(ftdi, SIO_RTS_CTS_HS) < 0) {
		fprintf(stderr, "Unable to set flow control %s\n", ftdi_get_error_string(ftdi));
		ftdi_usb_close(ftdi);
		ftdi_free(ftdi);
		return EXIT_FAILURE;
	}

	if (dist) {
		if (strcmp(interm, "fft") == 0) {
			op_state = FFT;
		} else if (strcmp(interm, "window") == 0) {
			op_state = WINDOW;
		} else if (strcmp(interm, "fir") == 0) {
			op_state = FIR;
		} else if (strcmp(interm, "raw") == 0) {
			op_state = RAW;
		}
		ftdi_err = ftdi_write_data(ftdi, &op_state, 1);
		if (ftdi_err < 0) {
			if (ftdi_err == -666) {
				fputs("Failed to write to radar. Device "
				      "unavailable.\n",
				      stderr);
			} else {
				fputs("Failed to write to radar.\n", stderr);
			}
			ftdi_usb_close(ftdi);
			ftdi_free(ftdi);
			return EXIT_FAILURE;
		}

		/* Tell plotting program how to interpret data. */
		fmode = fopen("data/mode", "w");
		fprintf(fmode, "%s", interm);
		fclose(fmode);

		/* Uses libusb asynchronous transfers for
		 * high-performance data streaming. It continually
		 * transfers data until an error occurs in the
		 * callback, or the callback returns a nonzero
		 * value. The last 2 arguments specify the number of
		 * packets per transfer (each packet is 512 bytes) and
		 * the number of transfers per callback,
		 * respectively. */
		ftdi_err = ftdi_readstream(ftdi, read_callback, NULL, 8, 256);
		if (ftdi_err < 0 && !exit_requested) {
			ftdi_usb_close(ftdi);
			ftdi_free(ftdi);
			exit(1);
		}
	} else {
		fprintf(stderr, "Angle operation is not yet implemented. Exiting.\n");
		ftdi_usb_close(ftdi);
		ftdi_free(ftdi);
		return EXIT_FAILURE;
	}

	fprintf(stderr, "Capture ended.\n");
	ftdi_usb_close(ftdi);
	ftdi_free(ftdi);
}
