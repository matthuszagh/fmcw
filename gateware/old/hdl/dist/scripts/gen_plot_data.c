#include <bitmanip.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define PACKET_LEN 8

void seek_header(FILE *f)
{
	unsigned char c;
	while (1) {
		c = getc(f);
		if (BITSET(c, 7) && !BITSET(c, 6) && !BITSET(c, 5) && !BITSET(c, 4)) {
			long pos = ftell(f) - 1;
			fseek(f, pos, SEEK_SET);
			return;
		}
	}
}

void read_packet(FILE *f, unsigned char *packet)
{
	for (int i = 0; i < PACKET_LEN; ++i) {
		unsigned char c;
		c = fgetc(f);
		packet[i] = c;
	}
}

/**
 * The full data payload.
 *
 * sub_payloads             : The individual sub-payloads.
 *
 * extract_sub_payload_data : Extract data for each sub-payload.
 *
 * get_write_data           : Process a single value to write to an
 *                            output file.
 */
struct payload {
	struct sub_payload *sub_payloads;
	void (*extract_sub_payload_data)(struct sub_payload *sub_payloads, int nsubs,
					 unsigned char *packet);
	int (*get_write_data)(struct sub_payload *sub_payloads, int nsubs);
};

/**
 * A single unit of data from a payload.
 *
 * lsb : The lower bit index (inclusive) of the piece of data. The LSB
 *       index of the payload is 0. Include all start and stop bits
 *       when considering the index.
 *
 * msb : The upper bit index (inclusive) of the data.
 *
 * s   : 1 if the data should be interpreted as 2s complement,
 *       0 otherwise.
 *
 * val : Integral value of the data.
 */
struct sub_payload {
	int lsb;
	int msb;
	int s;
	int val;
};

void raw_adc_extract_data(struct sub_payload *sub_payloads, int nsubs, unsigned char *packet)
{
	int *bit_array = malloc(8 * PACKET_LEN * sizeof(int));
	for (int i = 0; i < PACKET_LEN; ++i) {
		add_byte_bits_to_bit_array(packet[i], bit_array, 8 * i);
	}

	for (int i = 0; i < nsubs; ++i) {
		int lsb = sub_payloads[i].lsb;
		int msb = sub_payloads[i].msb;
		int nbits = msb - (lsb - 1);
		int byte_array_sz = round_up(nbits, 8);
		unsigned char *byte_array = malloc(byte_array_sz);
		memset(byte_array, 0, byte_array_sz);
		bit_subarray_to_byte_array(bit_array, lsb, msb, byte_array);
		if (sub_payloads[i].s) {
			sub_payloads[i].val = byte_array_to_int(byte_array, nbits);
		} else {
			sub_payloads[i].val = byte_arr_2_uint(byte_array, byte_array_sz);
		}

		free(byte_array);
	}

	free(bit_array);
}

int raw_adc_get_write_data(struct sub_payload *sub_payloads, int nsubs)
{
	return sub_payloads[0].val;
}

int main()
{
	struct sub_payload sub_payloads[1] = {{.lsb = 31, .msb = 55, .s = 1, .val = 0}};
	struct payload raw_adc = {.sub_payloads = sub_payloads,
				  .extract_sub_payload_data = &raw_adc_extract_data,
				  .get_write_data = &raw_adc_get_write_data};

	FILE *fin;
	fin = fopen("../read.bin", "rb");
	if (!fin) {
		fputs("Failed to open input file. Exiting...", stderr);
		return EXIT_FAILURE;
	}

	FILE *fout;
	fout = fopen("plot_data.dec", "w");
	if (!fout) {
		fputs("Failed to open output file. Exiting...", stderr);
		return EXIT_FAILURE;
	}

	fseek(fin, 0, SEEK_END);
	long end = ftell(fin);
	rewind(fin);

	unsigned char packet[PACKET_LEN];
	unsigned char last_packet[PACKET_LEN];
	memset(packet, 0, PACKET_LEN);

	int second_packet = 0;
	seek_header(fin);
	while (ftell(fin) != end) {
		read_packet(fin, packet);
		if (second_packet) {
			second_packet = 0;
			if (memcmp(packet, last_packet, PACKET_LEN) != 0) {
				seek_header(fin);
			} else {
				raw_adc.extract_sub_payload_data(sub_payloads,
								 COUNT_OF(sub_payloads), packet);
				int val = raw_adc.get_write_data(sub_payloads,
								 COUNT_OF(sub_payloads));
				fprintf(fout, "%d\n", val);
			}
		} else {
			second_packet = 1;
			memcpy(last_packet, packet, PACKET_LEN);
		}
	}

	fclose(fin);
	fclose(fout);
}
