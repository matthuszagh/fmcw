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

/**
 * Calculate the parity bit of a data packet.
 */
int parity(uint64_t data)
{
	int nbits;
	int parity;
	int i;

	nbits = 8 * sizeof(data);
	parity = 0;
	for (i = 0; i < nbits; ++i) {
		parity ^= (data & (1 << i)) >> i;
	}

	return parity;
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
	int exp_parity;
	int val_parity;

	val_parity = ((((uint64_t)1) << 59) & val) >> 59;
	exp_parity = parity(subw_val(val, 4, 55, 0));

	header = val >> (8 * (PACKET_LEN - 1) + 4);
	tail = (val & '\xf');

	/* return header == 8 && tail == 0 && val_parity == exp_parity; */
	return header == 8 && tail == 0;
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
		/* Convert to big endian to be independent of the
		 * CPU's native endianness. */
		rdval = htobe64(rdval);
		if (!dvalid(rdval)) {
			second_val = 0;
			seek_header(fin);
		} else {
			if (second_val) {
				if (rdval == last_val) {
					int fft;
					int ctr;
					int tx_re;
					fft = subw_val(rdval, 4, 25, 1);
					ctr = subw_val(rdval, 29, 10, 0);
					tx_re = subw_val(rdval, 39, 1, 0);
					fprintf(fout, "%8d %8u %3d\n", fft, ctr, tx_re);

					second_val = 0;
				}
			} else {
				second_val = 1;
			}
			last_val = rdval;
		}
	}

	fclose(fin);
	fclose(fout);
}
// Local Variables:
// rmsbolt-command: "clang -O3"
// rmsbolt-asm-format: "intel"
// rmsbolt-disassemble: nil
// End:
