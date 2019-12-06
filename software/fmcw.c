#include "bitmanip.h"
#include <bits/stdint-uintn.h>
#include <ftdi.h>
#include <limits.h>
#include <math.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define PACKET_LEN 8
/* number of bytes in a data payload */
#define PAYLOAD_SIZE 510
#define FFT_LEN 1024
#define BUFSIZE 2048

/* Valid messages to send radar. */
#define IDLE 0
#define FFT 1
#define WINDOW 2
#define FIR 3
#define RAW 4

/**
 * Return the integral value of the @PACKET_LEN bytes of buffer, @buf.
 */
static uint64_t get_value(uint8_t *buf);

/** TODO
 */
unsigned int bitrev(unsigned int v, int num_bits);

/**
 * Ensure data is in a valid state. This means that it contains the
 * appropriate header and stop sequence and has the correct parity
 * bit.
 */
int dvalid(uint64_t val);

static int exit_requested = 0;
static uint32_t start = 0;
static uint32_t offset = 0;
static int fn = 0;
static uint64_t last_val;
static int second_val;
static int last_fft;
static unsigned int last_ctr;
static unsigned int last_rev_ctr;
static int last_tx_re;
static int coverage;
/* record if each sample is found (1) or missed (0). */
static int idx_ctr[FFT_LEN];
/* raw samples */
static int64_t raw_a[FFT_LEN];
static int64_t raw_b[FFT_LEN];
/* fir output */
static int64_t fir_a[FFT_LEN];
static int64_t fir_b[FFT_LEN];
/* kaiser window output */
static int64_t window[FFT_LEN];
/* Fully-processed FFT data. */
static int fft_data[FFT_LEN];

static unsigned char op_state = IDLE;
static int report_loss = 0;

/* static FILE *raw_file; */

struct readstream_data {
	struct ftdi_context *ftdi;
	FTDIStreamCallback *callback;
	void *userdata;
	int packetsPerTransfer;
	int numTransfers;
};

static void write_fft(FILE *f);
static void write_raw(FILE *f);
static void write_window(FILE *f);
static void write_fir(FILE *f);
static void flush_data(int fn);
static void proc_fft(uint64_t rdval);
static void proc_window(uint64_t rdval);
static void proc_raw(uint64_t rdval);
static void proc_fir(uint64_t rdval);
/**
 * Perform a linear interpolation of any samples missing from the
 * array pointed to by @data. @valid points to an array of equal
 * length to @data. Each entry is either a 1 or 0, where 1 indicates
 * valid data and 0 indicates data is missing. @len is the number of
 * items in each array.
 */
static void interp_lin(int *data, int *valid, int len);
static int read_callback(uint8_t *buffer, int length, FTDIProgressInfo *progress, void *userdata);
static void *producer_fn(void *arg);
static void *consumer_fn(void *arg);
static void *monitor_input(void *arg);

struct buffer {
	uint8_t buf[BUFSIZE];
	int occupied;
	int nextin;
	int nextout;
	pthread_mutex_t mutex;
	pthread_cond_t more;
	pthread_cond_t less;
};

int main(int argc, char **argv)
{
	struct ftdi_context *ftdi = NULL;
	int ftdi_err;
	/* void *prod_ret; */
	int opt;
	int dist;
	char interm[10];
	FILE *fmode = NULL;
	pthread_t producer_thread;
	pthread_t consumer_thread;
	pthread_t input_monitor_thread;

	memset(interm, 0, 10);
	dist = 1;
	while ((opt = getopt(argc, argv, "hla:i:")) != -1) {
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
		case 'l':
			report_loss = 1;
			/* fft data is used as a premise for measuring
			 * data loss. */
			strcpy(interm, "fft");
			dist = 1;
			break;
		case 'h':
			printf("Usage: %s [OPTION]\n\n"
			       "  -h  display this message and exit\n\n"
			       "  -a  specify radar action\n"
			       "      values: dist or angle (defaults to dist)\n\n"
			       "  -i  get data from an intermediary step\n"
			       "      values: raw, fir, window, or fft (defaults to fft)\n"
			       "      fft retrieves fully processed output\n\n"
			       "  -l  display packet loss statistics\n"
			       "      does not perform any other processing\n\n",
			       argv[0]);
			goto cleanup;
		default:
			break;
		}
	}

	if (!interm[0]) {
		strcpy(interm, "fft");
	}

	if ((ftdi = ftdi_new()) == 0) {
		fprintf(stderr, "ftdi_new failed\n");
		goto cleanup;
	}

	if (ftdi_set_interface(ftdi, INTERFACE_A) < 0) {
		fprintf(stderr, "ftdi_set_interface failed\n");
		goto cleanup;
	}

	if (ftdi_usb_open_desc(ftdi, 0x0403, 0x6010, NULL, NULL) < 0) {
		fprintf(stderr, "Can't open ftdi device: %s\n", ftdi_get_error_string(ftdi));
		goto cleanup;
	}

	/* When the host PC requests a read, the FTDI device will only
	 * send data if the number of bytes requested is available. If
	 * not, the FTDI waits until the bytes are available before
	 * sending, or until the latency timer (1-255ms) has
	 * expired. */
	if (ftdi_set_latency_timer(ftdi, 2)) {
		fprintf(stderr, "Can't set latency, Error %s\n", ftdi_get_error_string(ftdi));
		goto cleanup;
	}

	/* Configures FT2232H for synchronous FIFO mode. */
	if (ftdi_set_bitmode(ftdi, 0xff, BITMODE_SYNCFF) < 0) {
		fprintf(stderr, "Can't set synchronous fifo mode, Error %s\n",
			ftdi_get_error_string(ftdi));
		goto cleanup;
	}

	/* Unfortunately this is maxed out on linux as 16KB even
	 * though FTDI recommends setting it to 64KB. */
	ftdi_read_data_set_chunksize(ftdi, 16384);

	if (ftdi_setflowctrl(ftdi, SIO_RTS_CTS_HS) < 0) {
		fprintf(stderr, "Unable to set flow control %s\n", ftdi_get_error_string(ftdi));
		goto cleanup;
	}

	struct buffer buf = {.buf = {0}, .occupied = 0, .nextin = 0, .nextout = 0};
	struct readstream_data prod_fn_arg = {.ftdi = ftdi,
					      .callback = read_callback,
					      .userdata = &buf,
					      .packetsPerTransfer = 8,
					      .numTransfers = 256};

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
			goto cleanup;
		}

		/* Tell plotting program how to interpret data. */
		fmode = fopen("data/mode", "w");
		if (!fmode) {
			fputs("Failed to open mode file.\n", stderr);
			goto cleanup;
		}
		fprintf(fmode, "%s", interm);
		fclose(fmode);

		pthread_create(&producer_thread, NULL, &producer_fn, &prod_fn_arg);
		pthread_create(&consumer_thread, NULL, &consumer_fn, &buf);

		pthread_create(&input_monitor_thread, NULL, &monitor_input, NULL);

		fputs("Type 'q' to terminate data capture.\n> ", stdout);
		pthread_join(input_monitor_thread, NULL);
		/* TODO get return value. */
		/* pthread_join(producer_thread, NULL); */
		pthread_cancel(consumer_thread);
		pthread_cancel(consumer_thread);
		/* ftdi_err = *(int *)prod_ret; */
		/* if (ftdi_err < 0 && !exit_requested) { */
		/* 	goto cleanup; */
		/* } */
	} else {
		fputs("Angle operation is not yet implemented. Exiting.\n", stderr);
		goto cleanup;
	}

	fprintf(stderr, "Capture ended.\n");
cleanup:
	ftdi_usb_close(ftdi);
	ftdi_free(ftdi);
}

uint64_t get_value(uint8_t *buf)
{
	int i;
	uint64_t res;

	i = 0;
	res = 0;
	while (i < 8) {
		add_byte_to_word(&res, 8 * (7 - i), buf[i]);
		++i;
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
	/* TODO change char_bit to 8? */
	r >>= sizeof(v) * CHAR_BIT - num_bits;
	return r;
}

int dvalid(uint64_t val)
{
	uint8_t header;
	uint8_t tail;

	header = val >> (8 * (PACKET_LEN - 1));
	tail = (val & '\xf');

	return header == 128 && tail == 0;
}

void write_fft(FILE *f)
{
	int i;

	for (i = 0; i < FFT_LEN / 2; ++i) {
		fprintf(f, "%8d %8u\n", fft_data[i], i);
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

/* TODO consider renaming since this just writes data to a file it
 * doesn't flush it to disk. */
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
	switch (op_state) {
	case FFT:
		write_fft(fout);
		break;
	case WINDOW:
		write_window(fout);
		break;
	case FIR:
		write_fir(fout);
		break;
	case RAW:
		write_raw(fout);
		break;
	}
	fclose(fout);
}

void interp_lin(int *data, int *valid, int len)
{
	int i;
	int j;
	int last_dat;
	int last_i;
	double inc_val;

	last_i = -1;
	for (i = 0; i < len; ++i) {
		if (valid[i]) {
			/* if starting data is invalid, copy the first
			 * valid data there. */
			if (last_i == -1) {
				for (j = last_i + 1; j < i; ++j) {
					data[j] = data[i];
				}
			} else {
				for (j = last_i + 1; j < i; ++j) {
					inc_val =
						((double)data[i] - (double)last_dat) / (i - last_i);
					data[j] = (int)(inc_val * (j - last_i) + last_dat);
				}
			}
			last_dat = data[i];
			last_i = i;
		}
	}
	/* fill any missing data at the end with the last valid
	 * value. */
	if (last_i != len - 1) {
		for (j = last_i + 1; j < i; ++j) {
			inc_val = ((double)data[i] - (double)last_dat) / (i - last_i);
			data[j] = (int)(inc_val * (j - last_i));
		}
	}
}

void proc_fft(uint64_t rdval)
{
	int fft;
	int fft_res;
	unsigned int ctr;
	unsigned int rev_ctr;
	int tx_re;
	int i;

	fft = subw_val(rdval, 4, 25, 1);
	ctr = subw_val(rdval, 29, 10, 0);
	tx_re = subw_val(rdval, 39, 1, 0);

	if (last_ctr == ctr && last_tx_re != tx_re) {
		fft_res = (int)sqrt(pow(fft, 2) + pow(last_fft, 2));
		rev_ctr = bitrev(ctr, 10);
		if (rev_ctr > last_rev_ctr) {
			idx_ctr[ctr] = 1;
			fft_data[ctr] = fft_res;
		} else {
			if (report_loss) {
				double cvg_sum;

				cvg_sum = 0;
				for (i = 0; i < FFT_LEN; ++i) {
					cvg_sum += idx_ctr[i];
					idx_ctr[i] = 0;
				}
				printf("coverage: %2.0f\n", 100 * cvg_sum / FFT_LEN);
			} else {
				interp_lin(fft_data, idx_ctr, FFT_LEN);
				flush_data(fn);
				++fn;
				for (i = 0; i < FFT_LEN; ++i) {
					fft_data[i] = 0;
					idx_ctr[i] = 0;
				}
			}
		}
		last_rev_ctr = rev_ctr;
	}
	last_fft = fft;
	last_ctr = ctr;
	last_tx_re = tx_re;
}

void proc_window(uint64_t rdval)
{
	int win;
	unsigned int ctr;

	win = subw_val(rdval, 4, 14, 1);
	ctr = subw_val(rdval, 18, 10, 0);

	++idx_ctr[ctr];
	window[ctr] += win;
	/* if (avg_ctr == AVG_INDEX) { */
	/* 	avg_ctr = 0; */
	/* 	flush_data(fn); */
	/* 	++fn; */
	/* } else { */
	/* 	++avg_ctr; */
	/* } */
}

void proc_raw(uint64_t rdval)
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
	/* if (avg_ctr == AVG_INDEX) { */
	/* 	avg_ctr = 0; */
	/* 	flush_data(fn); */
	/* 	++fn; */
	/* } else { */
	/* 	++avg_ctr; */
	/* } */
}

void proc_fir(uint64_t rdval)
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
	/* if (avg_ctr == AVG_INDEX) { */
	/* 	avg_ctr = 0; */
	/* 	flush_data(fn); */
	/* 	++fn; */
	/* } else { */
	/* 	++avg_ctr; */
	/* } */
}

int read_callback(uint8_t *buffer, int length, FTDIProgressInfo *progress, void *userdata)
{
	int i;
	uint64_t rdval;
	struct readstream_data *ftdi_data;
	struct buffer *shared_buf;

	ftdi_data = (struct readstream_data *)userdata;
	shared_buf = (struct buffer *)ftdi_data->userdata;

	/* We check every time less is signaled since the consumer
	 * won't signal that every byte. */
	while (shared_buf->occupied + length >= BUFSIZE) {
		pthread_cond_wait(&shared_buf->less, &shared_buf->mutex);
	}

	for (i = 0; i < length; ++i) {
		shared_buf->buf[shared_buf->nextin++] = buffer[i];
		shared_buf->nextin %= BUFSIZE;
		++shared_buf->occupied;
	}
	pthread_cond_signal(&shared_buf->more);

	return exit_requested ? 1 : 0;
}

void *producer_fn(void *arg)
{
	struct readstream_data *data;
	struct buffer *userdata;
	int ret_val;

	data = (struct readstream_data *)arg;
	userdata = (struct buffer *)data->userdata;

	pthread_mutex_lock(&userdata->mutex);

	/* Uses libusb asynchronous transfers for high-performance
	 * data streaming. It continually transfers data until an
	 * error occurs in the callback, or the callback returns a
	 * nonzero value. The last 2 arguments specify the number of
	 * packets per transfer (each packet is 512 bytes) and the
	 * number of transfers per callback, respectively. */
	ret_val = ftdi_readstream(data->ftdi, data->callback, data, data->packetsPerTransfer,
				  data->numTransfers);

	pthread_mutex_unlock(&userdata->mutex);
	/* return ret_val; */
	return NULL;
}

void *consumer_fn(void *arg)
{
	struct buffer *shared_buf;
	uint64_t rdval;
	uint64_t last_val;
	uint8_t *packet_buf = malloc(PACKET_LEN * sizeof(uint8_t));
	int i;
	int j;
	int occupied_cmp;

	shared_buf = (struct buffer *)arg;
	memset(packet_buf, 0, PACKET_LEN * sizeof(uint8_t));

	pthread_mutex_lock(&shared_buf->mutex);

	/* TODO use cleaner way of breaking out. */
	while (1) {
		occupied_cmp = shared_buf->occupied - PAYLOAD_SIZE > 8 ? shared_buf->occupied : 8;
		/* Wait for at least `PAYLOAD_SIZE' bytes of data so
		 * we don't waste time switching between threads. */
		while (shared_buf->occupied <= PAYLOAD_SIZE) {
			pthread_cond_wait(&shared_buf->more, &shared_buf->mutex);
		}
		while (shared_buf->occupied >= occupied_cmp) {
			i = 0;
			while (i + shared_buf->nextout < BUFSIZE && i < 8) {
				packet_buf[i] = shared_buf->buf[i + shared_buf->nextout];
				++i;
			}
			j = i;
			while (i < 8) {
				packet_buf[i] = shared_buf->buf[i - j];
				++i;
			}

			rdval = get_value(packet_buf);
			if (dvalid(rdval)) {
				if (second_val) {
					if (rdval == last_val) {
						switch (op_state) {
						case FFT:
							proc_fft(rdval);
							break;
						case WINDOW:
							proc_window(rdval);
							break;
						case FIR:
							proc_fir(rdval);
							break;
						case RAW:
							proc_raw(rdval);
							break;
						}
						second_val = 0;
					}
				} else {
					second_val = 1;
				}
				last_val = rdval;
				shared_buf->nextout += PACKET_LEN;
				shared_buf->occupied -= PACKET_LEN;
			} else {
				second_val = 0;
				++shared_buf->nextout;
				--shared_buf->occupied;
			}
			shared_buf->nextout %= BUFSIZE;
		}

		pthread_cond_signal(&shared_buf->less);
	}

	free(packet_buf);
	pthread_mutex_unlock(&shared_buf->mutex);
}

void *monitor_input(void *arg)
{
	char c;

	while ((c = getchar()) != 'q') {
		if (c == '\n') {
			fputs("Unrecognized input.\n> ", stdout);
		}
	}
	return NULL;
}
