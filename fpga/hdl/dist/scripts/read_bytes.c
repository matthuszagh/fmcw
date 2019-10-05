#include <bitmanip.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int fft_re_valid(int val, int last_val, int override) { return 1; }

int fft_im_valid(int val, int last_val, int override) { return 1; }

static int num_empty_bytes = 0;

int fft_ctr_valid(int val, int last_val, int override)
{
	if (override) {
		return 1;
	} else {
		if (val == 0 && num_empty_bytes > 10) {
			return 1;
		} else {
			if (num_empty_bytes > 0) {
				return 0;
			} else {
				int nbits = 10;
				if (bitrev(last_val, nbits) + 1 == bitrev(val, nbits)) {
					return 1;
				} else {
					num_empty_bytes = 0;
					return 0;
				}
			}
		}
	}
}

struct payload {
	// Payload identifier. Used to name output files.
	char name[20];
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

	// ADC output
	/* struct payload payloads[2] = {{.name = "chan_a", */
	/* 			       .lower_idx = 4, */
	/* 			       .upper_idx = 15, */
	/* 			       .sign = 1, */
	/* 			       .val = 0, */
	/* 			       .override = 0, */
	/* 			       .valid = &fft_re_valid}, */
	/* 			      {.name = "discard", */
	/* 			       .lower_idx = 16, */
	/* 			       .upper_idx = 63, */
	/* 			       .sign = 0, */
	/* 			       .val = 0, */
	/* 			       .override = 0, */
	/* 			       .valid = &fft_re_valid}}; */

	// FIR-filtered output
	/* struct payload payloads[2] = {{.name = "chan_filtered", */
	/* 			       .lower_idx = 4, */
	/* 			       .upper_idx = 17, */
	/* 			       .sign = 1, */
	/* 			       .val = 0, */
	/* 			       .override = 0, */
	/* 			       .valid = &fft_re_valid}, */
	/* 			      {.name = "discard", */
	/* 			       .lower_idx = 18, */
	/* 			       .upper_idx = 63, */
	/* 			       .sign = 0, */
	/* 			       .val = 0, */
	/* 			       .override = 0, */
	/* 			       .valid = &fft_re_valid}}; */

	// FFT input
	/* struct payload payloads[4] = {{.name = "fft_in", */
	/* 			       .lower_idx = 4, */
	/* 			       .upper_idx = 17, */
	/* 			       .sign = 1, */
	/* 			       .val = 0, */
	/* 			       .override = 0, */
	/* 			       .valid = &fft_re_valid}, */
	/* 			      {.name = "fft_en", */
	/* 			       .lower_idx = 18, */
	/* 			       .upper_idx = 18, */
	/* 			       .sign = 0, */
	/* 			       .val = 0, */
	/* 			       .override = 0, */
	/* 			       .valid = &fft_re_valid}, */
	/* 			      {.name = "fft_sync", */
	/* 			       .lower_idx = 19, */
	/* 			       .upper_idx = 19, */
	/* 			       .sign = 0, */
	/* 			       .val = 0, */
	/* 			       .override = 0, */
	/* 			       .valid = &fft_re_valid}, */
	/* 			      {.name = "discard", */
	/* 			       .lower_idx = 20, */
	/* 			       .upper_idx = 63, */
	/* 			       .sign = 0, */
	/* 			       .val = 0, */
	/* 			       .override = 0, */
	/* 			       .valid = &fft_re_valid}}; */

	// FFT w0_re
	/* struct payload payloads[6] = {{.name = "fft_w0_re", */
	/* 			       .lower_idx = 4, */
	/* 			       .upper_idx = 28, */
	/* 			       .sign = 1, */
	/* 			       .val = 0, */
	/* 			       .override = 0, */
	/* 			       .valid = &fft_re_valid}, */
	/* 			      {.name = "fft_en", */
	/* 			       .lower_idx = 29, */
	/* 			       .upper_idx = 29, */
	/* 			       .sign = 0, */
	/* 			       .val = 0, */
	/* 			       .override = 0, */
	/* 			       .valid = &fft_re_valid}, */
	/* 			      {.name = "fft_sync", */
	/* 			       .lower_idx = 30, */
	/* 			       .upper_idx = 30, */
	/* 			       .sign = 0, */
	/* 			       .val = 0, */
	/* 			       .override = 0, */
	/* 			       .valid = &fft_re_valid}, */
	/* 			      {.name = "pll_lock", */
	/* 			       .lower_idx = 31, */
	/* 			       .upper_idx = 31, */
	/* 			       .sign = 0, */
	/* 			       .val = 0, */
	/* 			       .override = 0, */
	/* 			       .valid = &fft_re_valid}, */
	/* 			      {.name = "pll2_lock", */
	/* 			       .lower_idx = 32, */
	/* 			       .upper_idx = 32, */
	/* 			       .sign = 0, */
	/* 			       .val = 0, */
	/* 			       .override = 0, */
	/* 			       .valid = &fft_re_valid}, */
	/* 			      {.name = "discard", */
	/* 			       .lower_idx = 31, */
	/* 			       .upper_idx = 63, */
	/* 			       .sign = 0, */
	/* 			       .val = 0, */
	/* 			       .override = 0, */
	/* 			       .valid = &fft_re_valid}}; */

	// FFT output
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

	char fout_hex_names[num_payloads][40];
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

	char fout_dec_names[num_payloads][40];
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
							fseek(fout_dec[j],
							      fout_dec_last[j] - ftell(fout_dec[j]),
							      SEEK_END);
							long dec_pos = ftell(fout_dec[j]);
							ftruncate(fileno(fout_dec[j]), dec_pos);

							fseek(fout_hex[j],
							      fout_hex_last[j] - ftell(fout_hex[j]),
							      SEEK_END);
							long hex_pos = ftell(fout_hex[j]);
							ftruncate(fileno(fout_hex[j]), hex_pos);
						}
						i = 3;
					}

					free(byte_array);
					free(hex_str);
				}
				num_empty_bytes = 0;
			}
		} else {
			if (bitset_array(c, header, COUNT_OF(header))) {
				dvalid = 1;
				bit_pos = add_byte_bits_to_bit_array(c, bit_array, 0);
			} else {
				++num_empty_bytes;
			}
		}
	}

	free(bit_array);
	for (int i = 0; i < num_payloads; ++i) {
		fclose(fout_hex[i]);
		fclose(fout_dec[i]);
	}
	fclose(fin);

	// compute FFT magnitude. Once the data looks right, this
	// should be made realtime.
	if (num_payloads > 2 && strncmp(payloads[1].name, "fft_re", strlen("fft_re")) == 0 &&
	    strncmp(payloads[2].name, "fft_im", strlen("fft_im")) == 0) {

		FILE *f_fft_re = fopen("data/fft_re.dec", "r");
		if (!f_fft_re) {
			fputs("Failed to open data/fft_re.dec.\n", stderr);
			return EXIT_FAILURE;
		}

		FILE *f_fft_im = fopen("data/fft_im.dec", "r");
		if (!f_fft_im) {
			fputs("Failed to open data/fft_im.dec.\n", stderr);
			return EXIT_FAILURE;
		}

		FILE *f_fft = fopen("data/fft.dec", "w");
		if (!f_fft) {
			fputs("Failed to open data/fft.dec\n", stderr);
			return EXIT_FAILURE;
		}

		char *re_line = malloc(100);
		char *im_line = malloc(100);
		while (fgets(re_line, 100, f_fft_re) != NULL &&
		       fgets(im_line, 100, f_fft_im) != NULL) {
			double mag = sqrt(pow(atoi(re_line), 2) + pow(atoi(im_line), 2));
			if (mag != mag) {
				fprintf(f_fft, "%d\n", 0);
			} else {
				fprintf(f_fft, "%f\n", mag);
			}
		}
		free(re_line);
		free(im_line);
		fclose(f_fft);
		fclose(f_fft_re);
		fclose(f_fft_im);
	}
}
