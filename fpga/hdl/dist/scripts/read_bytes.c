#include <bitmanip.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int fft_re_valid(int val, int last_val, int override) { return 1; }

int fft_im_valid(int val, int last_val, int override) { return 1; }

int fft_ctr_valid(int val, int last_val, int override)
{
	if (override) {
		return 1;
	} else {
		if (val == 0) {
			return 1;
		} else {
			int nbits = 10;
			if (bitrev(last_val, nbits) + 1 == bitrev(val, nbits))
				return 1;
			else
				return 0;
		}
	}
}

struct payload {
	// Payload identifier. Used to name output files.
	char name[10];
	// Index of MSB bit (big endian). Indices start at 0.
	int lower_idx;
	// Index of LSB bit.
	int upper_idx;
	// 0 for unsigned value, 1 for signed value.
	int sign;
	// current value
	int val;
	// override validity check (if 1)
	int override;
	// check whether retrieved payload data is valid. If yes,
	// return 1, otherwise return 0. An invalid payload also
	// invalidates any other data in the same payload as well as
	// the payloads surrounding it.
	int (*valid)();
};

int main()
{
	/* read_samples("../read.bin", "data.hex", 4); */
	/* gen_dec_file("data.hex", "data.dec", 25); */
	char *fname = "../read.bin";
	char *data_dir = "data/";

	struct payload payloads[3] = {{.name = "fft_ctr",
				       .lower_idx = 4,
				       .upper_idx = 13,
				       .sign = 0,
				       .val = 0,
				       .override = 0,
				       .valid = &fft_ctr_valid},
				      {.name = "fft_re",
				       .lower_idx = 14,
				       .upper_idx = 38,
				       .sign = 1,
				       .val = 0,
				       .override = 0,
				       .valid = &fft_re_valid},
				      {.name = "fft_im",
				       .lower_idx = 39,
				       .upper_idx = 63,
				       .sign = 1,
				       .val = 0,
				       .override = 0,
				       .valid = &fft_im_valid}};

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
	// tracks start position of last write. Useful for removing
	// last written value.
	long fout_hex_last[num_payloads];
	for (int i = 0; i < num_payloads; ++i) {
		fout_hex[i] = fopen(fout_hex_names[i], "w");
		if (!fout_hex[i]) {
			fprintf(stderr, "Failed to open output file: %s.\n", fout_hex_names[i]);
			return EXIT_FAILURE;
		}
		fout_hex_last[i] = 0;
	}

	char fout_dec_names[num_payloads][20];
	for (int i = 0; i < num_payloads; ++i) {
		strcpy(fout_dec_names[i], data_dir);
		strcat(fout_dec_names[i], payloads[i].name);
		strcat(fout_dec_names[i], ".dec");
	}

	FILE *fout_dec[num_payloads];
	long fout_dec_last[num_payloads];
	for (int i = 0; i < num_payloads; ++i) {
		fout_dec[i] = fopen(fout_dec_names[i], "w");
		if (!fout_dec[i]) {
			fprintf(stderr, "Failed to open output file: %s.\n", fout_dec_names[i]);
			return EXIT_FAILURE;
		}
		fout_dec_last[i] = 0;
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

					int new_val;

					if (payloads[i].sign) {
						new_val = byte_array_to_int(byte_array, nbits);
					} else {
						new_val =
							byte_arr_2_uint(byte_array, byte_array_sz);
					}

					if (payloads[i].valid(new_val, payloads[i].val,
							      payloads[i].override)) {
						if (payloads[i].override) {
							payloads[i].override = 0;
						}
						fout_hex_last[i] = ftell(fout_hex[i]);
						fout_dec_last[i] = ftell(fout_dec[i]);

						payloads[i].val = new_val;
						fprintf(fout_dec[i], "%d\n", new_val);
						byte_array_to_hex_str(byte_array, byte_array_sz,
								      hex_str);
						fprintf(fout_hex[i], "%s\n", hex_str);
					} else {
						payloads[i].override = 1;
						for (int j = i; j < num_payloads; ++j) {
							ftruncate(fileno(fout_dec[j]),
								  fout_dec_last[j]);
							ftruncate(fileno(fout_hex[j]),
								  fout_hex_last[j]);
						}
						i = 3;
					}

					free(byte_array);
					free(hex_str);
				}
			}
		} else {
			if (bitset_array(c, header, COUNT_OF(header))) {
				dvalid = 1;
				bit_pos = add_byte_bits_to_bit_array(c, bit_array, 0);
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
