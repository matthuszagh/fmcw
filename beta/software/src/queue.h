/**
 * Fixed-size FIFO-queue.
 *
 * It is up to the user to ensure that the queue is not overwritten or
 * overread. Use one of the appropriate functions to ensure this is
 * never done, as the behavior after that is undefined. This is done
 * expressely for performance reasons.
 */
#ifndef __QUEUE_H__
#define __QUEUE_H__

#include <stddef.h>
#include <stdlib.h>

struct Queue {
	size_t maxsize;
	int *buf;
	/* heads point to the next location to read or write. */
	int *read_head;
	int *write_head;
	size_t size;
};

struct Queue *queue_new(size_t size);
void queue_free(struct Queue *queue);
void queue_push(struct Queue *queue, int val);
int queue_pop(struct Queue *queue);
/**
 * Returns the amount of free space left in the queue.
 */
size_t queue_space(struct Queue *queue);
/**
 * Returns 1 if the queue is full, 0 otherwise.
 */
size_t queue_full(struct Queue *queue);
/**
 * Returns 1 if the queue is empty, 0 otherwise.
 */
size_t queue_empty(struct Queue *queue);
/**
 * Jump the write pointer back @n positions. This can be used to undo
 * the last @n writes. This does not check whether the jump will move
 * the write head past the read head, which would render the queue
 * behavior unspecified! It simply ensures that the write head wraps
 * around at the lower boundary and size is adjusted
 * appropriately. Since it assumes you have only called this when
 * you're sure the write head will not pass the read head, it will
 * also not check for multiple wraps.
 */
void queue_jump_back(struct Queue *queue, size_t n);

#endif
