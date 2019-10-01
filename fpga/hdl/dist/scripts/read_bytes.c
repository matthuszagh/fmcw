#include <bitmanip.h>
#include <stdio.h>
#include <stdlib.h>

int read_samples(char *fin, char *fout)
{
	unsigned char c;
	FILE *fp = fopen(fin, "rb");
	if (!fp) {
		fputs("Failed to open input file.\n", stderr);
		return EXIT_FAILURE;
	}

	FILE *fpout = fopen(fout, "w");
	if (!fpout) {
		fputs("Failed to open output file.\n", stderr);
		return EXIT_FAILURE;
	}

	fseek(fp, 0, SEEK_END);
	long flen = ftell(fp);
	rewind(fp);

	size_t byte_ctr = 0;
	char *indata = malloc(3);
	indata[2] = '\0';
	char *outdata = malloc(5);
	outdata[4] = '\0';
	while (ftell(fp) != flen) {
		c = getc(fp);
		if (byte_ctr == 1 || byte_ctr == 2) {
			indata[byte_ctr - 1] = c;
			++byte_ctr;
		} else {
			if (byte_ctr == 3) {
				byte_ctr = 0;
				byte_2_hex(indata[0], &outdata[0]);
				byte_2_hex(indata[1], &outdata[2]);
				fprintf(fpout, "%s\n", outdata);
			} else {
				if (c == 255) {
					byte_ctr = 1;
				}
			}
		}
	}

	fclose(fp);
	fclose(fpout);
	free(indata);
	free(outdata);

	return 0;
}

int gen_dec_file(char *fin, char *fout)
{
	char c;
	FILE *fp = fopen(fin, "r");
	if (!fp) {
		fputs("Failed to open input file.\n", stderr);
		return EXIT_FAILURE;
	}

	FILE *fpout = fopen(fout, "w");
	if (!fpout) {
		fputs("Failed to open output file.\n", stderr);
		return EXIT_FAILURE;
	}

	char *line = malloc(100);
	memset(line, 0, 100);
	size_t row = 0;
	while ((c = getc(fp)) != EOF) {
		if (c != '\n') {
			line[row] = c;
			++row;
		} else {
			int nbits = 14;
			int val = hex_str_2_int(line, nbits);
			int min = -(1 << (nbits - 1));
			int max = (1 << (nbits - 1)) - 1;
			// crude means of error detection
			if (val >= min && val <= max)
				fprintf(fpout, "%d\n", hex_str_2_int(line, nbits));

			memset(line, 0, 100);
			row = 0;
		}
	}
	free(line);
	fclose(fp);
	fclose(fpout);

	return 0;
}

int main()
{
	read_samples("../read_filtered.txt", "data_filtered.txt");
	gen_dec_file("data_filtered.txt", "data_filtered_dec.txt");
}
