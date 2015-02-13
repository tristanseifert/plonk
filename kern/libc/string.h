#include "stdint.h"

#ifndef STRING_H
#define STRING_H

// string specifics
size_t strlen(const char *str);

char* strtok(char *s, const char *delim);
char* strchr(const char *s, int c);
char* strsep(char **stringp, const char *delim);

int strcmp(const char* s1, const char* s2);
int strncmp(const char* s1, const char* s2, size_t n);

char *strcpy(char *dest, const char* src);
char *strncpy(char *dest, const char *src, size_t n);

char *strcat(char *dest, const char *src);

// memory-related
int memcmp(const void* ptr1, const void* ptr2, size_t num);
void* memchr(void* ptr, uint8_t value, size_t num);

void* memset(void* ptr, uint8_t value, size_t num);
void* memclr(void* ptr, size_t num);

#endif
