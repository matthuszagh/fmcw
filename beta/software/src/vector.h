#ifndef __VECTOR_H__
#define __VECTOR_H__

#include <stddef.h>

/** Simple vector implementation
 *
 */
struct Vector {
	unsigned char *buf;
	size_t size;
	size_t capacity;
};

struct Vector *vector_new();

void vector_free(struct Vector *vec);

/** Push data to vector
 *
 */
size_t vector_push(struct Vector *vec, unsigned char *data, size_t nbytes);
/** Empty vector of all data.
 *
 */
void vector_empty(struct Vector *vec);
/** Adjust vector capacity.
 *
 */
size_t vector_resize(struct Vector *vec, size_t newsize);

void vector_reverse(struct Vector *vec);

#endif
