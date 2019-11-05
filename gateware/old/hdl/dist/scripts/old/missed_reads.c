#include <stdio.h>
#include <stdlib.h>

// Setup the FPGA to send an 8-bit counter.

// indicates data has been duplicated by sender
#define DUPLICATE 1

long seek_dup(FILE *f)
{
	unsigned char last_c;
	int started = 0;
	unsigned char c;
	while (1) {
		c = getc(f);
		if (!started) {
			started = 1;
		} else {
			if (c == last_c) {
				return ftell(f) - 2;
			}
		}
		last_c = c;
	}
}

int main()
{
	FILE *fin;
	fin = fopen("../read.bin", "rb");
	if (!fin) {
		fputs("Failed to open input file. Exiting...", stderr);
		return EXIT_FAILURE;
	}

	fseek(fin, 0, SEEK_END);
	long end = ftell(fin);
	rewind(fin);

	unsigned char c;
	unsigned char last_val;
	int missed_reads = 0;
	int started = 0;

#if DUPLICATE == 1
	long start_pos = seek_dup(fin);
	fseek(fin, start_pos, SEEK_SET);
	unsigned char c2;

	while (ftell(fin) != end) {
		c = getc(fin);
		c2 = getc(fin);
		if (c == c2) {
			if (!started) {
				started = 1;
			} else {
				if (c != (unsigned char)(last_val + 1)) {
					++missed_reads;
				}
			}
		}
		last_val = c2;
	}
#else
	while (ftell(fin) != end) {
		c = getc(fin);
		if (!started) {
			started = 1;
		} else {
			if (c != last_val + 1) {
				++missed_reads;
			}
		}
		last_val = c;
	}
#endif

	printf("missed reads: %f%%\n", 100.0 * (double)missed_reads / (double)end);

	fclose(fin);
}
