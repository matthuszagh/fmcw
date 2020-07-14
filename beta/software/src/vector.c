#include "vector.h"
#include <stdlib.h>

#define INIT_SIZE 8

struct Vector *vector_new()
{
	unsigned char *buf = malloc(INIT_SIZE * sizeof(unsigned char));
	struct Vector *vec = malloc(sizeof(struct Vector));
	vec->buf = buf;
	vec->size = 0;
	vec->capacity = INIT_SIZE;

	return vec;
}

void vector_free(struct Vector *vec)
{
	free(vec->buf);
	free(vec);
}

size_t vector_push(struct Vector *vec, unsigned char *data, size_t size)
{
	while (vec->size + size > vec->capacity) {
		vector_resize(vec, 2 * vec->capacity);
	}

	for (size_t i = 0; i < size; ++i) {
		vec->buf[vec->size] = data[i];
		++vec->size;
	}

	return size;
}

void vector_empty(struct Vector *vec) { vec->size = 0; }

size_t vector_resize(struct Vector *vec, size_t newsize)
{
	if (newsize < vec->size) {
		return 0;
	}

	unsigned char *newbuf = malloc(newsize * sizeof(unsigned char));
	if (newbuf == NULL) {
		return 0;
	}

	for (size_t i = 0; i < vec->size; ++i) {
		newbuf[i] = vec->buf[i];
	}
	free(vec->buf);
	vec->buf = newbuf;

	vec->capacity = newsize;

	return newsize;
}

void vector_reverse(struct Vector *vec)
{
	unsigned char *newbuf = malloc(vec->capacity * sizeof(unsigned char));
	for (size_t i = 0; i < vec->size; ++i) {
		newbuf[i] = vec->buf[vec->size - i - 1];
	}
	free(vec->buf);
	vec->buf = newbuf;
}
