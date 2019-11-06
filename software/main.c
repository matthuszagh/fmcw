#define _DEFAULT_SOURCE

#include "bitmanip.h"
#include <bits/stdint-uintn.h>
#include <endian.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define PACKET_LEN 8

/* TODO move relevant code from read.c into this file. We want to read
 * data from the FPGA and convert it to a form usable for plots at the
 * same time. */

/**
 * Find the first byte for which the MSB nibble is 0x8.
 */
void seek_header(FILE *f)
{
	unsigned char c;
	while (1) {
		c = getc(f);
		if (c >> 4 == 8) {
			long pos = ftell(f) - 1;
			fseek(f, pos, SEEK_SET);
			return;
		}
	}
}

int main(int argc, char **argv)
{
	char *fin_name;
	char *fout_name;
	FILE *fin;
	FILE *fout;
	long end;
	uint64_t rdval;
	uint64_t last_val;
	int second_val;

	fin_name = "read.bin";
	fout_name = "plot.dec";

	if (argc == 2) {
		fin_name = argv[1];
	}

	fin = fopen(fin_name, "rb");
	if (!fin) {
		fputs("Failed to open input file. Exiting...", stderr);
		return EXIT_FAILURE;
	}

	fout = fopen(fout_name, "w");
	if (!fout) {
		fputs("Failed to open output file. Exiting...", stderr);
		return EXIT_FAILURE;
	}

	fseek(fin, 0, SEEK_END);
	end = ftell(fin);
	rewind(fin);

	rdval = 0ul;

	second_val = 0;
	seek_header(fin);
	while (ftell(fin) + PACKET_LEN <= end) {
		if (fread(&rdval, sizeof(uint64_t), 1, fin) < 1) {
			fputs("Failed to read from input file. Exiting...", stderr);
			return EXIT_FAILURE;
		}
		/* Convert to big endian. This allows the code to be
		 * independent of your CPU's native endianness. */
		rdval = htobe64(rdval);
		if (rdval >> (8 * (PACKET_LEN - 1) + 4) != 8 || (rdval & '\xf') != 0) {
			second_val = 0;
			seek_header(fin);
		} else {
			if (second_val) {
				second_val = 0;
				if (rdval != last_val) {
					seek_header(fin);
				} else {
					int fft_re;
					fft_re = subw_val(rdval, 8, 25, 1);
					fprintf(fout, "%d\n", fft_re);
				}
			} else {
				second_val = 1;
				last_val = rdval;
			}
		}
	}

	fclose(fin);
	fclose(fout);
}
