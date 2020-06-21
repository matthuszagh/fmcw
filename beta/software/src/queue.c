#include "queue.h"

int *_head_inc(struct Queue *queue, int *head)
{
	if (head == &queue->buf[queue->maxsize - 1]) {
		head = &queue->buf[0];
	} else {
		++head;
	}
	return head;
}

struct Queue *queue_new(size_t size)
{
	struct Queue *queue;

	queue = malloc(sizeof(struct Queue));
	queue->maxsize = size;
	queue->buf = malloc(size * sizeof(int));
	queue->read_head = &(queue->buf[0]);
	queue->write_head = queue->read_head;
	queue->size = 0;

	return queue;
}

void queue_free(struct Queue *queue)
{
	free(queue->buf);
	free(queue);
}

void queue_push(struct Queue *queue, int val)
{
	*queue->write_head = val;
	++queue->size;
	queue->write_head = _head_inc(queue, queue->write_head);
}

int queue_pop(struct Queue *queue)
{
	int val;

	val = *queue->read_head;
	--queue->size;
	queue->read_head = _head_inc(queue, queue->read_head);
	return val;
}

size_t queue_space(struct Queue *queue) { return queue->maxsize - queue->size; }
size_t queue_full(struct Queue *queue) { return queue_space(queue) == 0; }
size_t queue_empty(struct Queue *queue) { return queue_space(queue) == queue->maxsize; }

void queue_jump_back(struct Queue *queue, size_t n)
{
	int *queue_min = &queue->buf[0];
	size_t lower_space = queue->write_head - queue_min;
	if (n <= lower_space) {
		queue->write_head -= n;
	} else {
		size_t wrap = lower_space - n - 1;
		queue->write_head = &queue->buf[queue->maxsize - 1] - wrap;
	}
	queue->size -= n;
}
