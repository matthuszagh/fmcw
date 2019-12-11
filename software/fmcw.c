#include "bitmanip.h"
#include "bits/getopt_core.h"
#include <bits/stdint-uintn.h>
#include <ftdi.h>
#include <limits.h>
#include <math.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define PACKET_LEN 8
/* number of bytes in a data payload */
#define PAYLOAD_SIZE 510
#define FFT_LEN 1024
#define RAW_LEN 8000
#define BUFSIZE 2048
/* Indicates a command to Python subprocess. */
#define CMD 1
#define DATA 0

/* TODO needed? */
static int exit_requested = 0;
static time_t start_time;

enum Plot { TIME = 0, HIST };
/* FPGA expects these values. Don't change them unless you also change
 * the Verilog code. */
enum Out { FFT = 1, WIND, FIR, RAW };
struct cmd_flags {
	enum Plot plt;
	enum Out out;
	/* set to 1 to enable algo, or 0 to disable. */
	int fir;
	int wind;
	int fft;
};

enum Interpolate { NON = 0, LIN = 1 };
/* TODO this struct feels like a loose collection of slightly
 * related data. There should be a better way to organize
 * this. */
struct data {
	/* These are send to the python subprocess, so their size must
	 * be well defined. */
	int32_t *a_arr;
	int32_t *b_arr;
	unsigned int *ctr_arr;
	int second_valp;
	int last_a;
	int last_b;
	unsigned int last_ctr;
	unsigned int last_rev_ctr;
	FILE *pipe;
	enum Interpolate interp;
	/* 1: report packet loss statistics; 0: don't report
	 * statistics */
	int stat;
	struct cmd_flags flags;
};

struct thread_buffer {
	uint8_t buf[BUFSIZE];
	int occupied;
	int nextin;
	int nextout;
	pthread_mutex_t mutex;
	pthread_cond_t more;
	pthread_cond_t less;
};

struct producer_data {
	struct ftdi_context *ftdi;
	FTDIStreamCallback *callback;
	void *userdata;
	int packetsPerTransfer;
	int numTransfers;
};

struct consumer_data {
	struct thread_buffer *buf;
	struct data *data;
};

static unsigned char algo_bit_flags(struct cmd_flags *flags);
/**
 * Issue a command to the python subprocess. The python program
 * initially expects a "prepare" byte. The prepare byte has a value of
 * CMD if a sequence of commands will follow and a value of DATA if
 * data will follow (see the function send_cmd). Behavior is undefined
 * if data is sent before the first command. If a command is
 * specified, the next byte will indicate the plot type (using the
 * enum Plot values). Then the output type is specified (using the
 * enum Out type). Lastly, a byte is sent specifying the algos to
 * use. The LSB specifies FIR filtering. The next bit is for
 * windowing, and the final bit is for the FFT. After the command has
 * been sent the python subprocess expects another "prepare" byte.
 */

static void send_cmd(struct data *data);
/**
 * Send data to the python subprocess. The first byte must be a
 * prepare byte. The second is a 4-byte timestamp associated with the
 * data. The timestamp has type uint32_t and represents the number of
 * milliseconds since the start time. It then sends FFT_LEN packets of
 * 4 bytes for FFT data, 2xFFT_LEN packets of 4 bytes (first FFT_LEN
 * packets channel A, second channel B) for FIR or windowed data, or
 * 2xRAW_LEN packets of 4 bytes for raw data.
 */
static void send_data(struct data *data);
static void proc_fft(uint64_t rdval, struct data *data);
static void proc_window(uint64_t rdval, struct data *data);
static void proc_raw(uint64_t rdval, struct data *data);
static void proc_fir(uint64_t rdval, struct data *data);
/**
 * Perform a linear interpolation of any samples missing from the
 * array pointed to by @data. @valid points to an array of equal
 * length to @data. Each entry is either a 1 or 0, where 1 indicates
 * valid data and 0 indicates data is missing. @len is the number of
 * items in each array.
 */
static void interp_lin(int *data, unsigned int *valid, int len);
static int read_callback(uint8_t *buffer, int length, FTDIProgressInfo *progress, void *userdata);
static void *producer_fn(void *arg);
static void *consumer_fn(void *arg);
static void *monitor_input(void *arg);
/**
 * Return the integral value of the @PACKET_LEN bytes of buffer, @buf.
 */
static uint64_t get_value(uint8_t *buf);
unsigned int bitrev(unsigned int v, int num_bits);
/**
 * Ensure data is in a valid state. This means that it contains the
 * appropriate header and stop sequence and has the correct parity
 * bit.
 */
int dvalid(uint64_t val);

int main(int argc, char **argv)
{
	struct ftdi_context *ftdi = NULL;
	int ftdi_err;
	/* void *prod_ret; */
	int opt;
	/* TODO shouldn't be done this way. */
	int dist;
	int plot_flag_passed;
	int interm_flag_passed;
	unsigned char fpga_wrval;
	unsigned char python_wrval;
	pthread_t producer_thread;
	pthread_t consumer_thread;
	pthread_t input_monitor_thread;
	/* set argument defaults. */
	struct data data = {.interp = LIN,
			    .stat = 0,
			    .flags = {.out = FFT, .fir = 1, .wind = 1, .fft = 1},
			    .a_arr = NULL,
			    .b_arr = NULL,
			    .ctr_arr = NULL,
			    .pipe = NULL};

	dist = 1;
	plot_flag_passed = 0;
	interm_flag_passed = 0;
	while ((opt = getopt(argc, argv, "a:hi:n:p:su:")) != -1) {
		switch (opt) {
		case 'h':
			printf("Usage: %s [OPTION]\n\n"
			       "  -a  specify radar action\n"
			       "      values: 'dist' or 'angle' (defaults to dist)\n\n"
			       "  -h  display this message and exit\n\n"
			       "  -i  get data from an intermediary step\n"
			       "      values: 'raw', 'fir', 'window', or 'fft' (defaults to fft)\n"
			       "      fft retrieves fully processed output\n\n"
			       "  -n  interpolation method for missing data\n"
			       "      values: 'lin', 'none' (defaults to 'lin')\n"
			       "      If you specify none, all missing data will be set to 0.\n\n"
			       "  -p  plot type\n"
			       "      values: 'hist', 'time'\n"
			       "      default: fft->hist, rest->time\n"
			       "      NOTE: time plots are incompatible with FFT data.\n\n"
			       "  -s  display packet loss statistics\n"
			       "      does not perform any other processing\n\n"
			       "  -u  specifies algorithms to use\n"
			       "      Formatted as 3 numbers where a '1' indicates the algorithm\n"
			       "      should be used and a '0' indicates it should be skipped.\n"
			       "      The last set bit also determines what data is plotted.\n"
			       "      1st number: filter\n"
			       "      2nd number: window\n"
			       "      3rd number: fft\n"
			       "      default: 111\n"
			       "      NOTE: Currently only relates to software processing.\n"
			       "            For instance, if you specify '-i fft' and set\n"
			       "            any of these bits to 0, the FPGA will still\n"
			       "            perform all processing steps.\n"
			       "      example usage: 100 (perform filtering and nothing else)\n\n",
			       argv[0]);
			goto cleanup;
		case 'a':
			if (strcmp(optarg, "dist") != 0) {
				dist = 0;
			}
			/* dist=1 is default */
			break;
		case 'i':
			interm_flag_passed = 1;
			if (strcmp(optarg, "raw") == 0) {
				data.flags.out = RAW;
				data.a_arr = malloc(RAW_LEN * sizeof(int32_t));
				data.b_arr = malloc(RAW_LEN * sizeof(int32_t));
				data.ctr_arr = malloc(RAW_LEN * sizeof(int32_t));
				memset(data.a_arr, 0, RAW_LEN * sizeof(int32_t));
				memset(data.b_arr, 0, RAW_LEN * sizeof(int32_t));
				memset(data.ctr_arr, 0, RAW_LEN * sizeof(int32_t));
			} else if (strcmp(optarg, "fir") == 0) {
				data.flags.out = FIR;
				data.a_arr = malloc(FFT_LEN * sizeof(int32_t));
				data.b_arr = malloc(FFT_LEN * sizeof(int32_t));
				data.ctr_arr = malloc(FFT_LEN * sizeof(int32_t));
				memset(data.a_arr, 0, FFT_LEN * sizeof(int32_t));
				memset(data.b_arr, 0, FFT_LEN * sizeof(int32_t));
				memset(data.ctr_arr, 0, FFT_LEN * sizeof(int32_t));
			} else if (strcmp(optarg, "window") == 0) {
				data.flags.out = WIND;
				data.a_arr = malloc(FFT_LEN * sizeof(int32_t));
				data.b_arr = malloc(FFT_LEN * sizeof(int32_t));
				data.ctr_arr = malloc(FFT_LEN * sizeof(int32_t));
				memset(data.a_arr, 0, FFT_LEN * sizeof(int32_t));
				memset(data.b_arr, 0, FFT_LEN * sizeof(int32_t));
				memset(data.ctr_arr, 0, FFT_LEN * sizeof(int32_t));
			} else if (strcmp(optarg, "fft") == 0) {
				/* default value */
				data.a_arr = malloc(FFT_LEN * sizeof(int32_t));
				data.ctr_arr = malloc(FFT_LEN * sizeof(int32_t));
				memset(data.a_arr, 0, FFT_LEN * sizeof(int32_t));
				memset(data.ctr_arr, 0, FFT_LEN * sizeof(int32_t));
				/* don't compute a distance FFT for
				 * channel B. */
			} else {
				fprintf(stderr, "Invalid -i option: %s\n", optarg);
				goto cleanup;
			}
			break;
		case 'n':
			if (strcmp(optarg, "none") != 0) {
				data.interp = NON;
			} else if (strcmp(optarg, "lin") != 0) {
				/* default value */
			} else {
				fprintf(stderr, "Invalid -n option: %s\n", optarg);
				goto cleanup;
			}
			break;
		case 'p':
			plot_flag_passed = 1;
			if (strcmp(optarg, "hist") != 0) {
				data.flags.plt = HIST;
			} else if (strcmp(optarg, "time") != 0) {
				data.flags.plt = TIME;
			} else {
				fprintf(stderr, "Invalid -p option: %s\n", optarg);
				goto cleanup;
			}
			break;
		case 's':
			data.stat = 1;
			dist = 1;
			break;
		case 'u':
			if (strlen(optarg) != 3) {
				fprintf(stderr, "Invalid -u option: %s\n", optarg);
				goto cleanup;
			} else {
				/* if something other than 0 or 1 is
				 * specified, the default will be
				 * used. */
				if (optarg[0] == '0') {
					data.flags.fir = 0;
				}
				if (optarg[1] == '0') {
					data.flags.wind = 0;
				}
				if (optarg[2] == '0') {
					data.flags.fft = 0;
				}
			}
			break;
		default:
			break;
		}
	}

	if (!interm_flag_passed) {
		data.a_arr = malloc(FFT_LEN * sizeof(int32_t));
		data.ctr_arr = malloc(FFT_LEN * sizeof(int32_t));
		memset(data.a_arr, 0, FFT_LEN * sizeof(int32_t));
		memset(data.ctr_arr, 0, FFT_LEN * sizeof(int32_t));
	}

	if (!plot_flag_passed) {
		if (data.flags.fft) {
			data.flags.plt = HIST;
		} else {
			data.flags.plt = TIME;
		}
	}

	if (data.flags.plt == TIME && data.flags.out == FFT) {
		fputs("Invalid request: FFT time plot.\n", stderr);
		goto cleanup;
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

	struct thread_buffer buf = {.buf = {0}, .occupied = 0, .nextin = 0, .nextout = 0};
	struct consumer_data cons_fn_arg = {.buf = &buf, .data = &data};
	struct producer_data prod_fn_arg = {.ftdi = ftdi,
					    .callback = read_callback,
					    .userdata = &buf,
					    .packetsPerTransfer = 8,
					    .numTransfers = 256};

	fpga_wrval = data.flags.out;
	if (dist) {
		ftdi_err = ftdi_write_data(ftdi, &fpga_wrval, 1);
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

		/* this should be blocking, which we want. */
		data.pipe = popen("./plot.py", "w");
		start_time = time(NULL);

		pthread_create(&producer_thread, NULL, &producer_fn, &prod_fn_arg);
		pthread_create(&consumer_thread, NULL, &consumer_fn, &cons_fn_arg);
		pthread_create(&input_monitor_thread, NULL, &monitor_input, NULL);

		send_cmd(&data);

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
		fputs("Angle operation is not yet implemented.\n", stderr);
		goto cleanup;
	}

	fprintf(stderr, "Capture ended.\n");
cleanup:
	pclose(data.pipe);
	free(data.a_arr);
	free(data.b_arr);
	free(data.ctr_arr);
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

unsigned char algo_bit_flags(struct cmd_flags *flags)
{
	unsigned char res;

	res = 0;
	res |= flags->fir;
	res |= flags->wind << 1;
	res |= flags->fft << 2;
	return res;
}

/* TODO this always writes data without signaling data. It should
 * signal data and the python program should be made to support it. */
void send_cmd(struct data *data)
{
	unsigned char wrval;

	wrval = CMD;
	fwrite(&wrval, 1, 1, data->pipe);
	wrval = data->flags.plt;
	fwrite(&wrval, 1, 1, data->pipe);
	wrval = data->flags.out;
	fwrite(&wrval, 1, 1, data->pipe);
	wrval = algo_bit_flags(&data->flags);
	fwrite(&wrval, 1, 1, data->pipe);
}

void send_data(struct data *data)
{
	unsigned char wrval[4];
	int num_chans;
	int packet_len;
	uint32_t tsec;

	if (data->flags.out == RAW) {
		packet_len = RAW_LEN;
		num_chans = 2;
	} else {
		packet_len = FFT_LEN;
		if (data->flags.out == FFT) {
			num_chans = 1;
		} else {
			num_chans = 2;
		}
	}

	wrval[0] = DATA;
	fwrite(wrval, 1, 1, data->pipe);

	tsec = time(NULL);
	tsec -= start_time;
	fwrite(&tsec, sizeof(tsec), 1, data->pipe);

	fwrite(data->a_arr, sizeof(wrval), packet_len, data->pipe);
	if (num_chans == 2) {
		fwrite(data->b_arr, sizeof(wrval), packet_len, data->pipe);
	}
}

void interp_lin(int *data, unsigned int *valid, int len)
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

void proc_fft(uint64_t rdval, struct data *data)
{
	int32_t fft;
	int32_t fft_res;
	unsigned int ctr;
	unsigned int rev_ctr;
	int tx_re;
	int i;

	/* TODO magic numbers, use macros instead */
	fft = (int32_t)subw_val(rdval, 4, 25, 1);
	ctr = (unsigned int)subw_val(rdval, 29, 10, 0);
	tx_re = (int)subw_val(rdval, 39, 1, 0);

	if (data->last_ctr == ctr && data->last_b != tx_re) {
		fft_res = (int32_t)sqrt(pow(fft, 2) + pow(data->last_a, 2));
		rev_ctr = bitrev(ctr, 10);
		if (rev_ctr > data->last_rev_ctr) {
			data->ctr_arr[ctr] = 1;
			data->a_arr[ctr] = fft_res;
		} else {
			if (data->stat) {
				double cvg_sum;

				cvg_sum = 0;
				for (i = 0; i < FFT_LEN; ++i) {
					cvg_sum += data->ctr_arr[i];
					data->ctr_arr[i] = 0;
				}
				printf("coverage: %2.0f\n", 100 * cvg_sum / FFT_LEN);
			} else {
				if (data->interp == LIN) {
					interp_lin(data->a_arr, data->ctr_arr, FFT_LEN);
				}
				send_data(data);
			}
		}
		data->last_rev_ctr = rev_ctr;
	}
	data->last_a = fft;
	data->last_b = tx_re;
	data->last_ctr = ctr;
}

void proc_window(uint64_t rdval, struct data *data)
{
	int32_t chan_a;
	int32_t chan_b;
	unsigned int ctr;

	/* TODO magic numbers, use macros instead */
	chan_a = (int32_t)subw_val(rdval, 4, 14, 1);
	chan_b = (int32_t)subw_val(rdval, 18, 14, 1);
	ctr = (unsigned int)subw_val(rdval, 32, 10, 0);

	/* TODO most data is being written twice for some reason. >=
	 * is a temporary bandaid */
	if (ctr >= data->last_ctr) {
		data->ctr_arr[ctr] = 1;
		data->a_arr[ctr] = chan_a;
		data->b_arr[ctr] = chan_b;
	} else {
		if (data->interp == LIN) {
			interp_lin(data->a_arr, data->ctr_arr, FFT_LEN);
			interp_lin(data->b_arr, data->ctr_arr, FFT_LEN);
		}
		send_data(data);
	}
	data->last_ctr = ctr;
}

void proc_raw(uint64_t rdval, struct data *data)
{
	int32_t chan_a;
	int32_t chan_b;
	unsigned int ctr;

	/* TODO magic numbers, use macros instead */
	chan_a = (int32_t)subw_val(rdval, 4, 12, 1);
	chan_b = (int32_t)subw_val(rdval, 16, 12, 1);
	ctr = (unsigned int)subw_val(rdval, 28, 13, 0);

	/* TODO most data is being written twice for some reason. >=
	 * is a temporary bandaid */
	if (ctr >= data->last_ctr) {
		data->ctr_arr[ctr] = 1;
		data->a_arr[ctr] = chan_a;
		data->b_arr[ctr] = chan_b;
	} else {
		if (data->interp == LIN) {
			interp_lin(data->a_arr, data->ctr_arr, RAW_LEN);
			interp_lin(data->b_arr, data->ctr_arr, RAW_LEN);
		}
		send_data(data);
	}
	data->last_ctr = ctr;
}

void proc_fir(uint64_t rdval, struct data *data)
{
	int32_t chan_a;
	int32_t chan_b;
	unsigned int ctr;

	/* TODO magic numbers, use macros instead */
	chan_a = (int32_t)subw_val(rdval, 4, 14, 1);
	chan_b = (int32_t)subw_val(rdval, 18, 14, 1);
	ctr = (unsigned int)subw_val(rdval, 32, 10, 0);

	/* printf("%5d %5d %5d\n", ctr, last_ctr, chan_a); */
	/* TODO most data is being written twice for some reason. >=
	 * is a temporary bandaid */
	if (ctr >= data->last_ctr) {
		data->ctr_arr[ctr] = 1;
		data->a_arr[ctr] = chan_a;
		data->b_arr[ctr] = chan_b;
	} else {
		if (data->interp == LIN) {
			interp_lin(data->a_arr, data->ctr_arr, FFT_LEN);
			interp_lin(data->b_arr, data->ctr_arr, FFT_LEN);
		}
		send_data(data);
	}
	data->last_ctr = ctr;
}

int read_callback(uint8_t *buffer, int length, FTDIProgressInfo *progress, void *userdata)
{
	int i;
	uint64_t rdval;
	struct producer_data *ftdi_data;
	struct thread_buffer *shared_buf;

	ftdi_data = (struct producer_data *)userdata;
	shared_buf = (struct thread_buffer *)ftdi_data->userdata;

	/* We check every time less is signaled since the consumer
	 * won't signal less every byte. */
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
	struct producer_data *data;
	struct thread_buffer *userdata;
	int ret_val;

	data = (struct producer_data *)arg;
	userdata = (struct thread_buffer *)data->userdata;

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
	struct consumer_data *consumer_data;
	struct thread_buffer *buf;
	struct data *data;
	uint64_t rdval;
	uint64_t last_val;
	uint8_t *packet_buf = malloc(PACKET_LEN * sizeof(uint8_t));
	int i;
	int j;
	int occupied_cmp;

	consumer_data = (struct consumer_data *)arg;
	buf = consumer_data->buf;
	data = consumer_data->data;

	memset(packet_buf, 0, PACKET_LEN * sizeof(uint8_t));

	pthread_mutex_lock(&buf->mutex);

	/* TODO use cleaner way of breaking out. */
	while (1) {
		occupied_cmp = buf->occupied - PAYLOAD_SIZE > 8 ? buf->occupied : 8;
		/* Wait for at least `PAYLOAD_SIZE' bytes of data so
		 * we don't waste time switching between threads. */
		while (buf->occupied <= PAYLOAD_SIZE) {
			pthread_cond_wait(&buf->more, &buf->mutex);
		}
		while (buf->occupied >= occupied_cmp) {
			i = 0;
			while (i + buf->nextout < BUFSIZE && i < 8) {
				packet_buf[i] = buf->buf[i + buf->nextout];
				++i;
			}
			j = i;
			while (i < 8) {
				packet_buf[i] = buf->buf[i - j];
				++i;
			}

			rdval = get_value(packet_buf);
			if (dvalid(rdval)) {
				if (data->second_valp) {
					if (rdval == last_val) {
						switch (data->flags.out) {
						case FFT:
							proc_fft(rdval, data);
							break;
						case WIND:
							proc_window(rdval, data);
							break;
						case FIR:
							proc_fir(rdval, data);
							break;
						case RAW:
							proc_raw(rdval, data);
							break;
						}
						data->second_valp = 0;
					}
				} else {
					data->second_valp = 1;
				}
				last_val = rdval;
				buf->nextout += PACKET_LEN;
				buf->occupied -= PACKET_LEN;
			} else {
				data->second_valp = 0;
				++buf->nextout;
				--buf->occupied;
			}
			buf->nextout %= BUFSIZE;
		}

		pthread_cond_signal(&buf->less);
	}

	free(packet_buf);
	pthread_mutex_unlock(&buf->mutex);
}

/* TODO eventually monitor_input should permit changing state while
   running. The current difficulty with this is that it requires
   thread-safe access to data. */
void *monitor_input(void *arg)
{
	char c;

	while ((c = (char)getchar()) != 'q') {
		/* only send this once per set of characters. all
		 * character sequences must be entered with a
		 * terminated return so we use a newline. */
		if (c == '\n') {
			fputs("Unrecognized input.\n> ", stdout);
		}
	}
	return NULL;
}
