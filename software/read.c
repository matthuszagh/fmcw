#include "bitmanip.h"
#include <bits/stdint-uintn.h>
#include <ftdi.h>
#include <limits.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define PACKET_LEN 8
#define FFT_LEN 1024
/* Average samples over this number of reads. */
#define AVG_INDEX 30000
/* whether to subtract background signal. */
#define SUBTRACT_BACKGROUND 1

/**
 * Find the first byte for which the MSB nibble is 0x8.
 */
int seek_valid(uint8_t *buffer, int length, int *pos)
{
	while (*pos + 7 < length) {
		if (buffer[*pos] == 128 && buffer[*pos + 7] == 0) {
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
	int header;
	int tail;

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
/* static unsigned int last_ctr_rev; */
static int last_tx_re;
static int coverage;
/* keep track of the number of times a value is found for each bit
 * position. This is used to periodically divide the accumulator. */
static int idx_ctr[FFT_LEN];
/* Accumulate values and average periodically. This is used as a
 * solution for dropped values. */
static int64_t accum[FFT_LEN];
static int64_t backg[FFT_LEN];
static int backg_set = 0;
static int avg_ctr = 0;

/* void subtract_background() {} */

void flush_samples(int fn)
{
	int i;
	int ctr_rev;
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
	for (i = 0; i < FFT_LEN / 2; ++i) {
		if (idx_ctr[i] != 0) {
			accum[i] /= idx_ctr[i];
			/* if (backg_set) { */
			/* backg[i] = (backg[i] + accum[i]) / 2; */
			/* accum[i] -= backg[i]; */
			/* backg[i] = accum[i]; */
			/* } else { */
			/* 	backg_set = 1; */
			/* 	backg[i] = accum[i]; */
			/* } */

		} else {
			accum[i] = 0;
		}
		/* if (SUBTRACT_BACKGROUND) */
		/* 	subtract_background(); */

		fprintf(fout, "%8d %8u\n", accum[i], i);
		accum[i] = 0;
		idx_ctr[i] = 0;
	}
	fclose(fout);
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
					int fft;
					int fft_res;
					unsigned int ctr;
					/* unsigned int ctr_rev; */
					int tx_re;

					fft = subw_val(rdval, 4, 25, 1);
					ctr = subw_val(rdval, 29, 10, 0);
					tx_re = subw_val(rdval, 39, 1, 0);
					/* ctr_rev = bitrev(ctr, 10); */

					if (last_ctr == ctr && last_tx_re != tx_re) {
						fft_res = sqrt(pow(fft, 2) + pow(last_fft, 2));
						accum[ctr] += fft_res;
						++idx_ctr[ctr];
						if (avg_ctr == AVG_INDEX) {
							avg_ctr = 0;
							flush_samples(fn);
							++fn;
						} else {
							++avg_ctr;
						}
					}

					second_val = 0;
					last_fft = fft;
					last_ctr = ctr;
					/* last_ctr_rev = ctr_rev; */
					last_tx_re = tx_re;
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
	int err;

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

	/* Uses libusb asynchronous transfers for high-performance
	 * data streaming. It continually transfers data until an
	 * error occurs in the callback, or the callback returns a
	 * nonzero value. The last 2 arguments specify the number of
	 * packets per transfer (each packet is 512 bytes) and the
	 * number of transfers per callback, respectively. */
	err = ftdi_readstream(ftdi, read_callback, NULL, 8, 256);
	if (err < 0 && !exit_requested)
		exit(1);

	fprintf(stderr, "Capture ended.\n");
	ftdi_usb_close(ftdi);
	ftdi_free(ftdi);
}
// Local Variables:
// rmsbolt-command: "clang -O3"
// rmsbolt-asm-format: "intel"
// rmsbolt-disassemble: nil
// End:
