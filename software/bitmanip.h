#ifndef _BITMANIP_H_
#define _BITMANIP_H_

#include <stdint.h>

/** Constructs a word of data from a series of bytes.
 *
 * @w word to construct
 * @l LSB of byte to add
 * @b byte to add
 */
uint64_t add_byte_to_word(uint64_t w, int l, unsigned char b);

/** Extract a subword value from a full word.
 *
 * A full word contains 64 bits and may comprise any combination of
 * "subwords" within it. These are generally placed contiguously,
 * although that is not required. A start halfword of 0x8 is, however,
 * required and a terminating halfword of 0x0 is also required.
 * Subwords must be big-endian.
 *
 * example
 * {4'h8, 7'd0, sw3[11:0], sw2[11:0], sw1[19:0], 5'd0, 4'd0}
 *
 * l and n for sw1,2,3 would be ((41, 12), (29, 12), (9, 20))
 *
 * @w the original word
 * @l LSB of the value to extract
 * @n number of bits to extract, starting at p
 * @s 1 if two's complement, 0 if unsigned
 */
int64_t subw_val(uint64_t w, int l, int n, unsigned char s);

#endif
