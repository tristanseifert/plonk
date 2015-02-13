#ifndef NUM_H
#define NUM_H

char *itoa(int value, int base);
int atoi(const char *str);

long strtol(const char *nptr, char **endptr, int base);
unsigned long strtoul(const char *nptr, char **endptr, int base);

#endif
