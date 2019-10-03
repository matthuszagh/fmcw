#include <bitmanip.h>
#include <stdio.h>
#include <stdlib.h>

// Return 1 if the nth bit in a byte is set. Return 0 otherwise.
/* #define BITSET(c, n) ((c & (1u << n)) == (1u << n)) */

/* int read_samples(char *fin, char *fout, size_t n_packet_bytes) */
/* { */
/* 	unsigned char c; */
/* 	FILE *fp = fopen(fin, "rb"); */
/* 	if (!fp) { */
/* 		fputs("Failed to open input file.\n", stderr); */
/* 		return EXIT_FAILURE; */
/* 	} */

/* 	FILE *fpout = fopen(fout, "w"); */
/* 	if (!fpout) { */
/* 		fputs("Failed to open output file.\n", stderr); */
/* 		return EXIT_FAILURE; */
/* 	} */

/* 	fseek(fp, 0, SEEK_END); */
/* 	long flen = ftell(fp); */
/* 	rewind(fp); */

/* 	size_t byte_ctr = 0; */
/* 	char *indata = malloc(n_packet_bytes + 1); */
/* 	indata[n_packet_bytes] = '\0'; */
/* 	char *outdata = malloc(2 * n_packet_bytes + 1); */
/* 	outdata[2 * n_packet_bytes] = '\0'; */
/* 	while (ftell(fp) != flen) { */
/* 		c = getc(fp); */
/* 		if (byte_ctr >= 1 && byte_ctr <= n_packet_bytes) { */
/* 			indata[byte_ctr - 1] = c; */
/* 			++byte_ctr; */
/* 		} else { */
/* 			if (byte_ctr == n_packet_bytes + 1) { */
/* 				byte_ctr = 0; */
/* 				for (size_t i = 0; i < n_packet_bytes; ++i) { */
/* 					byte_2_hex(indata[i], &outdata[2 * i]); */
/* 				} */
/* 				fprintf(fpout, "%s\n", outdata); */
/* 			} else { */
/* 				if (c == 255) { */
/* 					byte_ctr = 1; */
/* 				} */
/* 			} */
/* 		} */
/* 	} */

/* 	fclose(fp); */
/* 	fclose(fpout); */
/* 	free(indata); */
/* 	free(outdata); */

/* 	return 0; */
/* } */

/* void read_samples(char *fname, int header, int num_payload_bits) {} */

/* int gen_dec_file(char *fin, char *fout, int nbits) */
/* { */
/* 	char c; */
/* 	FILE *fp = fopen(fin, "r"); */
/* 	if (!fp) { */
/* 		fputs("Failed to open input file.\n", stderr); */
/* 		return EXIT_FAILURE; */
/* 	} */

/* 	FILE *fpout = fopen(fout, "w"); */
/* 	if (!fpout) { */
/* 		fputs("Failed to open output file.\n", stderr); */
/* 		return EXIT_FAILURE; */
/* 	} */

/* 	char *line = malloc(100); */
/* 	memset(line, 0, 100); */
/* 	size_t row = 0; */
/* 	while ((c = getc(fp)) != EOF) { */
/* 		if (c != '\n') { */
/* 			line[row] = c; */
/* 			++row; */
/* 		} else { */
/* 			int val = hex_str_2_int(line, nbits); */
/* 			int min = -(1 << (nbits - 1)); */
/* 			int max = (1 << (nbits - 1)) - 1; */
/* 			// crude means of error detection */
/* 			if (val >= min && val <= max) { */
/* 				fprintf(stderr, */
/* 					"Error: value %d outside valid range of %d to %d.\n", val,
 */
/* 					min, max); */
/* 				free(line); */
/* 				return EXIT_FAILURE; */
/* 			} */

/* 			fprintf(fpout, "%d\n", hex_str_2_int(line, nbits)); */

/* 			memset(line, 0, 100); */
/* 			row = 0; */
/* 		} */
/* 	} */
/* 	free(line); */
/* 	fclose(fp); */
/* 	fclose(fpout); */

/* 	return 0; */
/* } */

/* int fft_in() */
/* { */
/* 	FILE *fin = fopen("data.bin", "rb"); */
/* 	if (!fin) { */
/* 		fputs("Failed to open input file.\n", stderr); */
/* 		return EXIT_FAILURE; */
/* 	} */

/* 	FILE *fout_hex = fopen("fft_in.hex", "w"); */
/* 	if (!fout_hex) { */
/* 		fputs("Failed to open output hex file.\n", stderr); */
/* 		return EXIT_FAILURE; */
/* 	} */

/* 	FILE *fout_dec = fopen("fft_in.dec", "w"); */
/* 	if (!fout_dec) { */
/* 		fputs("Failed to open output dec file.\n", stderr); */
/* 		return EXIT_FAILURE; */
/* 	} */

/* 	fseek(fin, 0, SEEK_END); */
/* 	long flen = ftell(fin); */
/* 	rewind(fin); */

/* 	unsigned char c; */
/* 	int dvalid = 0; */
/* 	while (ftell(fin) != flen) { */
/* 		c = getc(fin); */
/* 		if (!dvalid && c == 255) { */
/* 			dvalid = 1; */
/* 		} else { */
/* 			if (dvalid) { */

/* 			} */
/* 		} */
/* 	} */

/* 	fclose(fin); */
/* 	fclose(fout_hex); */
/* 	fclose(fout_dec); */
/* 	return 0; */
/* } */

struct payload {
	// Payload identifier. Used to name output files.
	char name[10];
	// Index of MSB bit (big endian). Indices start at 0.
	int lower_idx;
	// Index of LSB bit.
	int upper_idx;
	// 0 for unsigned value, 1 for signed value.
	int sign;
};

int main()
{
	/* read_samples("../read.bin", "data.hex", 4); */
	/* gen_dec_file("data.hex", "data.dec", 25); */
	char *fname = "../read.bin";
	char *data_dir = "data/";

	struct payload payloads[3] = {
		{"fft_ctr", 4, 13, 0}, {"fft_re", 14, 38, 1}, {"fft_im", 39, 63, 1}};

	FILE *fin = fopen(fname, "rb");
	if (!fin) {
		fprintf(stderr, "Failed to open input file: %s.\n", fname);
		return EXIT_FAILURE;
	}
	fseek(fin, 0, SEEK_END);
	long fin_end = ftell(fin);
	rewind(fin);

	int num_payloads = COUNT_OF(payloads);

	char fout_hex_names[num_payloads][30];
	for (int i = 0; i < num_payloads; ++i) {
		strcpy(fout_hex_names[i], data_dir);
		strcat(fout_hex_names[i], payloads[i].name);
		strcat(fout_hex_names[i], ".hex");
	}

	FILE *fout_hex[num_payloads];
	for (int i = 0; i < num_payloads; ++i) {
		fout_hex[i] = fopen(fout_hex_names[i], "w");
		if (!fout_hex[i]) {
			fprintf(stderr, "Failed to open output file: %s.\n", fout_hex_names[i]);
			return EXIT_FAILURE;
		}
	}

	char fout_dec_names[num_payloads][20];
	for (int i = 0; i < num_payloads; ++i) {
		strcpy(fout_dec_names[i], data_dir);
		strcat(fout_dec_names[i], payloads[i].name);
		strcat(fout_dec_names[i], ".dec");
	}

	FILE *fout_dec[num_payloads];
	for (int i = 0; i < num_payloads; ++i) {
		fout_dec[i] = fopen(fout_dec_names[i], "w");
		if (!fout_dec[i]) {
			fprintf(stderr, "Failed to open output file: %s.\n", fout_dec_names[i]);
			return EXIT_FAILURE;
		}
	}

	int header[4] = {7, 6, 5, 4};

	int *bit_array = malloc(sizeof(int) * (payloads[num_payloads - 1].upper_idx + 1));
	int bit_pos = 0;

	unsigned char c;
	int dvalid = 0; /* indicates reading payload data */
	while (ftell(fin) != fin_end) {
		c = getc(fin);
		if (dvalid) {
			bit_pos = add_byte_bits_to_bit_array(c, bit_array, bit_pos);
			if (bit_pos == payloads[num_payloads - 1].upper_idx + 1) {
				dvalid = 0;
				bit_pos = 0;
				for (int i = 0; i < num_payloads; ++i) {
					int nbits =
						payloads[i].upper_idx - (payloads[i].lower_idx - 1);
					int byte_array_sz = round_up(nbits, 8);
					unsigned char *byte_array = malloc(byte_array_sz);
					memset(byte_array, 0, byte_array_sz);
					char *hex_str = malloc(2 * byte_array_sz + 1);
					hex_str[2 * byte_array_sz] = '\0';
					bit_subarray_to_byte_array(bit_array, payloads[i].lower_idx,
								   payloads[i].upper_idx,
								   byte_array);
					if (payloads[i].sign) {
						fprintf(fout_dec[i], "%d\n",
							byte_array_to_int(byte_array, nbits));
					} else {
						fprintf(fout_dec[i], "%d\n",
							byte_arr_2_uint(byte_array, byte_array_sz));
					}
					byte_array_to_hex_str(byte_array, byte_array_sz, hex_str);
					fprintf(fout_hex[i], "%s\n", hex_str);
					free(byte_array);
					free(hex_str);
				}
			}
		} else {
			if (bitset_array(c, header, COUNT_OF(header))) {
				dvalid = 1;
				bit_pos += add_byte_bits_to_bit_array(c, bit_array, 0);
			}
		}
	}

	free(bit_array);
	for (int i = 0; i < num_payloads; ++i) {
		fclose(fout_hex[i]);
		fclose(fout_dec[i]);
	}
	fclose(fin);
}
