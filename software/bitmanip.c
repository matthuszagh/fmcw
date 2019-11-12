#include "bitmanip.h"

void add_byte_to_word(uint64_t *w, int l, uint8_t b)
{
	uint64_t bshift;
	bshift = (uint64_t)b;
	bshift <<= l;
	*w |= bshift;
}

int64_t subw_val(uint64_t w, int l, int n, unsigned char s)
{
	uint64_t mask;
	uint64_t lower_mask, upper_mask;
	uint64_t extract;
	int neg;

	mask = -1;
	lower_mask = mask >> (64 - l);
	upper_mask = mask << (l + n);
	mask = ~(upper_mask | lower_mask);

	extract = (w & mask) >> l;

	neg = extract & (1 << (n - 1));

	if (s && neg)
		return extract - (1 << n);

	return extract;
}
