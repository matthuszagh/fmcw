#include <ftdi.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define PACKETS_PER_TRANSFER 8
#define TRANSFERS_PER_CALLBACK 256
#define CHUNKSIZE 16384
/* Capture data for 10s unless user provides a value. */
#define CAPTURE_DEFAULT 10
#define START 0x5a
#define STOP 0xa5
#define DISABLE_LIVE_LOGGING 1
#define DECIMATE 20
#define FFT_LEN 1024
#define RAW_LEN (DECIMATE * FFT_LEN)
#define ADC_BITS 12
#define ADC_SIGN_MASK 0x800
#define NS_TO_S 1e-9
#define BYTE_BITS 8
#define VENDOR_ID 0x0403
#define MODEL_ID 0x6010
#define SIGN_EXTEND_12_16 0xf000

static uint8_t last;
/* Amount of time to test capture (in s). */
static double capture_time;
static struct timespec tp_start;
static struct timespec tp_stop;
static int capture_done;
static int byte_count;
static int count;
static int total_count;
static uint8_t buffer_last;

struct callback_data {
	FILE *logfile;
	int16_t *buf;
	FILE *pipe;
};

/* Elapsed time in seconds. */
static double elapsed_time()
{
	return ((double)tp_stop.tv_sec - (double)tp_start.tv_sec) +
	       (NS_TO_S * ((double)tp_stop.tv_nsec - (double)tp_start.tv_nsec));
}

static int16_t sign_extend(int16_t in)
{
	if ((ADC_SIGN_MASK & in) == ADC_SIGN_MASK) {
		return SIGN_EXTEND_12_16 | in;
	}
	return in;
}

static int callback(uint8_t *buffer, int length, FTDIProgressInfo *progress, void *userdata)
{
	uint8_t val;
	struct callback_data *data = (struct callback_data *)userdata;
	FILE *logfile = data->logfile;
	int16_t *buf = data->buf;
	FILE *pipe = data->pipe;

	if (capture_done) {
		return 1;
	}

	for (int i = 0; i < length; ++i) {
		if (buffer[i] == STOP) {
#if !DISABLE_LIVE_LOGGING
			printf("sequence length: %d / 20480\n", count);
#endif
			if (count == RAW_LEN) {
				/* fwrite(buf, sizeof(int16_t), RAW_LEN, pipe); */
				/* if (logfile != NULL) { */
				/* 	fwrite(buf, sizeof(int16_t), RAW_LEN, logfile); */
				/* } */
				/* printf("Wrote %d samples to pipe.\n", RAW_LEN); */
				/* for (int i = 0; i < RAW_LEN; ++i) { */
				/* 	printf("%4d: %hd\n", i, buf[i]); */
				/* } */
			}
			count = 0;
			byte_count = 0;
		} else if (buffer[i] == START) {
			byte_count = 0;
			count = 0;
		} else {
			/* printf("buffer: %hhx\n", buffer[i]); */
			if (byte_count % 2 == 1) {
				if (count < RAW_LEN) {
					uint8_t buf_last;
					if (i == 0) {
						buf_last = buffer_last;
					} else {
						buf_last = buffer[i - 1];
					}
					printf("buffer[i-1]: %0hhx\n", buf_last);
					printf("buffer[i]  : %0hhx\n", buffer[i]);
					buf[count] = sign_extend((int16_t)(buf_last << BYTE_BITS) |
								 (int16_t)buffer[i]);
					printf("buf[%4d]  : %hx\n\n", count, buf[count]);
				}
				++count;
			}
			++byte_count;
		}
	}
	total_count += length;
	buffer_last = buffer[length - 1];

	if (logfile != NULL) {
		size_t ret = fwrite(buffer, 1, length, logfile);
		if (ret != length) {
			fprintf(stderr, "Failed to write all bytes to logfile. Terminating.\n");
			exit(1);
		}
	}

	clock_gettime(CLOCK_MONOTONIC, &tp_stop);
	if (elapsed_time() > capture_time) {
		capture_done = 1;
		return 1;
	}
	return 0;
}

static void print_statistics()
{
	double t_elapse;

	t_elapse = elapsed_time();
	printf("Elapsed time: %fs\n", t_elapse);
	printf("Achieved throughput: %.4eB/s\n", (double)total_count / t_elapse);
}

int main(int argc, char **argv)
{
	struct ftdi_context *ftdi = NULL;
	int read_ret;
	int opt;
	FILE *logfile = NULL;

	struct callback_data callback_data = {
		.logfile = logfile, .buf = malloc(RAW_LEN * sizeof(int16_t)),
		/* .pipe = popen("/home/matt/src/fmcw-radar/beta/software/plot.py", "w") */
	};

	capture_time = CAPTURE_DEFAULT;
	while ((opt = getopt(argc, argv, "t:l:h")) != -1) {
		switch (opt) {
		case 'h':
			printf("Usage: %s [OPTION]\n"
			       "  -t  capture time (in seconds)\n"
			       "  -l  log file\n"
			       "  -h  display this message and exit\n",
			       argv[0]);
			return 0;
		case 't':
			capture_time = (double)atoi(optarg);
			break;
		case 'l':
			callback_data.logfile = fopen(optarg, "w");
			if (callback_data.logfile == NULL) {
				fprintf(stderr, "Failed to open log file. Terminating.\n");
				return 1;
			}
			break;
		}
	}

	if ((ftdi = ftdi_new()) == 0) {
		fprintf(stderr, "ftdi_new failed\n");
		fclose(callback_data.logfile);
		exit(1);
	}

	if (ftdi_set_interface(ftdi, INTERFACE_A) < 0) {
		fprintf(stderr, "ftdi_set_interface failed\n");
		fclose(callback_data.logfile);
		ftdi_free(ftdi);
		exit(1);
	}

	if (ftdi_usb_open_desc(ftdi, VENDOR_ID, MODEL_ID, NULL, NULL) < 0) {
		fprintf(stderr, "Can't open ftdi device: %s\n", ftdi_get_error_string(ftdi));
		fclose(callback_data.logfile);
		ftdi_free(ftdi);
		exit(1);
	}

	if (ftdi_set_latency_timer(ftdi, 2)) {
		fprintf(stderr, "Can't set latency, Error %s\n", ftdi_get_error_string(ftdi));
		fclose(callback_data.logfile);
		ftdi_usb_close(ftdi);
		ftdi_free(ftdi);
		exit(1);
	}

	/* Configures FT2232H for synchronous FIFO mode. */
	if (ftdi_set_bitmode(ftdi, 0xff, BITMODE_SYNCFF) < 0) {
		fprintf(stderr, "Can't set synchronous fifo mode, Error %s\n",
			ftdi_get_error_string(ftdi));
		fclose(callback_data.logfile);
		ftdi_usb_close(ftdi);
		ftdi_free(ftdi);
		exit(1);
	}

	/* Unfortunately this is maxed out on linux as 16KB even
	 * though FTDI recommends setting it to 64KB. */
	ftdi_read_data_set_chunksize(ftdi, CHUNKSIZE);

	if (ftdi_setflowctrl(ftdi, SIO_RTS_CTS_HS) < 0) {
		fprintf(stderr, "Unable to set flow control %s\n", ftdi_get_error_string(ftdi));
		fclose(callback_data.logfile);
		ftdi_usb_close(ftdi);
		ftdi_free(ftdi);
		exit(1);
	}

	clock_gettime(CLOCK_MONOTONIC, &tp_start);
	read_ret = ftdi_readstream(ftdi, callback, &callback_data, PACKETS_PER_TRANSFER,
				   TRANSFERS_PER_CALLBACK);
	print_statistics();
	fclose(callback_data.logfile);
	pclose(callback_data.pipe);
	free(callback_data.buf);
	ftdi_usb_close(ftdi);
	ftdi_free(ftdi);
	return 0;
}
