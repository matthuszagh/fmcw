#include <stdio.h>
#include <stdlib.h>

int main()
{
	FILE *fp = fopen("fftr22sdf_rom_s0_re.hex", "r");
	char *mem = malloc(1024 * 3 * sizeof(char));
	int c;
	/* char *infile = "fftr22sdf_rom_s0_re.hex"; */
	int i = 0;
	while ((c = getchar()) != EOF && c != '\n') {
		mem[i] = (char)c;
		++i;
	}
	for (size_t i = 0; i < sizeof(mem) / sizeof(char); ++i) {
		printf("%c", mem[i]);
	}
}
