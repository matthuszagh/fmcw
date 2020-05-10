#include <ftdi.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>

/* Test write streaming from FPGA to host PC.
 *
 * The FPGA sends an 8-bit counter that increments on each FTDI 60MHz
 * clock period. The first transmission value is 1, which should be
 * received by the host. The host PC checks for any lost bytes and
 * measures the transmission speed. This check does not try to be
 * smart about error-detection. If a bit is flipped, for instance it
 * will incorrectly state that all bytes between the last transmitted
 * value and this one were dropped. Similarly, since the subsequent
 * value will not be 1 greater than the error value, it will state
 * that all those bytes were dropped as well. It will not know if more
 * than 1 full packet was dropped.
 */

#define PACKETS_PER_TRANSFER 8
#define TRANSFERS_PER_CALLBACK 256
#define CHUNKSIZE 16384
/* Capture data for 60s unless user provides a value. */
#define CAPTURE_DEFAULT 10
/* Disable logging runtime statistics for much higher
 * throughputs. Final statistics will still be presented. */
#define DISABLE_RUNTIME_STATS 0

static u_long rx_bytes;
static u_long err_bytes;
static uint8_t last;
/* Amount of time to test capture (in s). */
static double capture_time;
static struct timespec tp_start;
static struct timespec tp_stop;
static int capture_done;

/* Elapsed time in seconds. */
static double elapsed_time()
{
	return ((double)tp_stop.tv_sec - (double)tp_start.tv_sec) +
	       (1e-9 * ((double)tp_stop.tv_nsec - (double)tp_start.tv_nsec));
}

/* Compute the number of bytes dropped between the current and last
 * value. */
static uint8_t missing(uint8_t curr, uint8_t last)
{
	if (curr >= last) {
		return curr - 1 - last;
	}
	return curr - 1 + (UINT8_MAX - last);
}

static int callback(uint8_t *buffer, int length, FTDIProgressInfo *progress, void *userdata)
{
	uint8_t val;
	FILE *logfile = (FILE *)userdata;

	if (capture_done) {
		return 1;
	}

	for (int i = 0; i < length; ++i) {
		val = (uint8_t)(*(buffer + i));
		if (val != (uint8_t)(last + 1)) {
			int num_missing;
			num_missing = missing(val, last);
			err_bytes += num_missing;
#if !DISABLE_RUNTIME_STATS
			printf("Dropped %u byte(s) at address %u (0x%08x).\n", num_missing,
			       rx_bytes, rx_bytes);
#endif
		}
		last = val;
		++rx_bytes;
	}

	if (logfile != NULL) {
		int ret = fwrite(buffer, 1, length, logfile);
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

	printf("%u bytes dropped out of %u total bytes received (%.2f%%).\n", err_bytes, rx_bytes,
	       100 * (double)err_bytes / (double)rx_bytes);
	t_elapse = elapsed_time();
	printf("Elapsed time: %fs\n", t_elapse);
	printf("Achieved throughput: %.4eB/s\n", (double)rx_bytes / t_elapse);
}

int main(int argc, char **argv)
{
	struct ftdi_context *ftdi = NULL;
	int read_ret;
	int opt;
	FILE *logfile = NULL;

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
			logfile = fopen(optarg, "w");
			if (logfile == NULL) {
				fprintf(stderr, "Failed to open log file. Terminating.\n");
				return 1;
			}
			break;
		}
	}

	if ((ftdi = ftdi_new()) == 0) {
		fprintf(stderr, "ftdi_new failed\n");
		fclose(logfile);
		exit(1);
	}

	if (ftdi_set_interface(ftdi, INTERFACE_A) < 0) {
		fprintf(stderr, "ftdi_set_interface failed\n");
		fclose(logfile);
		ftdi_free(ftdi);
		exit(1);
	}

	if (ftdi_usb_open_desc(ftdi, 0x0403, 0x6010, NULL, NULL) < 0) {
		fprintf(stderr, "Can't open ftdi device: %s\n", ftdi_get_error_string(ftdi));
		fclose(logfile);
		ftdi_free(ftdi);
		exit(1);
	}

	if (ftdi_set_latency_timer(ftdi, 2)) {
		fprintf(stderr, "Can't set latency, Error %s\n", ftdi_get_error_string(ftdi));
		fclose(logfile);
		ftdi_usb_close(ftdi);
		ftdi_free(ftdi);
		exit(1);
	}

	/* Configures FT2232H for synchronous FIFO mode. */
	if (ftdi_set_bitmode(ftdi, 0xff, BITMODE_SYNCFF) < 0) {
		fprintf(stderr, "Can't set synchronous fifo mode, Error %s\n",
			ftdi_get_error_string(ftdi));
		fclose(logfile);
		ftdi_usb_close(ftdi);
		ftdi_free(ftdi);
		exit(1);
	}

	/* Unfortunately this is maxed out on linux as 16KB even
	 * though FTDI recommends setting it to 64KB. */
	ftdi_read_data_set_chunksize(ftdi, CHUNKSIZE);

	if (ftdi_setflowctrl(ftdi, SIO_RTS_CTS_HS) < 0) {
		fprintf(stderr, "Unable to set flow control %s\n", ftdi_get_error_string(ftdi));
		fclose(logfile);
		ftdi_usb_close(ftdi);
		ftdi_free(ftdi);
		exit(1);
	}

	clock_gettime(CLOCK_MONOTONIC, &tp_start);
	read_ret = ftdi_readstream(ftdi, callback, logfile, PACKETS_PER_TRANSFER,
				   TRANSFERS_PER_CALLBACK);
	print_statistics();
	fclose(logfile);
	ftdi_usb_close(ftdi);
	ftdi_free(ftdi);
	return 0;
}
