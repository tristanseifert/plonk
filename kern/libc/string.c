#include <stdint.h>

#include "string.h"

/**
 * Counts the number of characters (that is, single-byte characters: this is a
 * single character in ASCII) in a string.
 */
size_t strlen(const char *str) {
    size_t ret = 0;
    
    while (str[ret] != 0x00) {
        ret++;
    }
    
    return ret;
}

/*
 * Separates string s by delim, returning either NULL if there is no more 
 * strings that can be split out, or the next split if there is any.
 */
char* strtok(char *s, const char *delim) {
    char *spanp;
    int c, sc;
    char *tok;
    static char *last;

    if (s == NULL && (s = last) == NULL)
        return NULL;

    // Skip (span) leading delimiters (s += strspn(s, delim), sort of).
cont:
    c = *s++;
    for (spanp = (char *)delim; (sc = *spanp++) != 0;) {
        if (c == sc)
            goto cont;
    }

    if (c == 0) { // no non-delimiter characters
        last = NULL;
        return NULL;
    }
    tok = s - 1;

    /*
     * Scan token (scan for delimiters: s += strcspn(s, delim), sort of).
     * Note that delim must have one NUL; we stop if we see that, too.
     */
    for (;;) {
        c = *s++;
        spanp = (char *) delim;
        do {
            if ((sc = *spanp++) == c) {
                if (c == 0)
                    s = NULL;
                else
                    s[-1] = 0;
                last = s;
                return tok;
            }
        } while (sc != 0);
    }
}

/*
 * Returns a pointer to the first occurrence of character c in string s.
 */
char* strchr(const char *s, int c) {
    const char ch = c;

    for ( ; *s != ch; s++)
        if (*s == '\0')
            return NULL;
    return (char *) s;
}

/*
 * Get next token from string *stringp, where tokens are possibly-empty
 * strings separated by characters from delim.  
 *
 * Writes NULs into the string at *stringp to end tokens.
 * delim need not remain constant from call to call.
 * On return, *stringp points past the last NUL written (if there might
 * be further tokens), or is NULL (if there are definitely no more tokens).
 *
 * If *stringp is NULL, strsep returns NULL.
 */
char* strsep(char **stringp, const char *delim) {
    char *s;
    const char *spanp;
    int c, sc;
    char *tok;

    if ((s = *stringp) == NULL) {
        return NULL;
    }

    for (tok = s;;) {
        c = *s++;
        spanp = delim;
        do {
            if ((sc = *spanp++) == c) {
                if (c == 0) {
                    s = NULL;
                } else {
                    s[-1] = 0;
                }

                *stringp = s;
                return tok;
            }
        } while (sc != 0);
    }
}

/*
 * Compares two strings.
 */
int strcmp(const char* s1, const char* s2) {
    while(*s1 && (*s1==*s2)) {
        s1++, s2++;
    }

    return *(const unsigned char*)s1 - *(const unsigned char*)s2;
}

/*
 * Compares n bytes of the two strings.
 */
int strncmp(const char* s1, const char* s2, size_t n) {
    while(n--) {
        if(*s1++!=*s2++) {
            return *(unsigned char*)(s1 - 1) - *(unsigned char*)(s2 - 1);
        }
    }
    
    return 0;
}

/*
 * Copies the input string into the buffer pointed to by destination. Does NOT
 * perform bound checking.
 */
char *strcpy(char *dest, const char* src) {
    char *ret = dest;
    
    while ((*dest++ = *src++));

    return ret;
}

/*
 * Copies n bytes from the source string to the destination buffer, filling the
 * destination with zeros if source ends prematurely.
 */
char *strncpy(char *dest, const char *src, size_t n) {
    char *ret = dest;
    do {
        if (!n--) {
            return ret;
        }
    } while ((*dest++ = *src++));
    
    while (n--) {
        *dest++ = 0;
    }

    return ret;
}

/*
 * Appends the null-terminated string pointed to by src to the one pointed to
 * by dest.
 */
char *strcat(char *dest, const char *src) {
    char *ret = dest;
    while (*dest) {
        dest++;
    }
    
    while ((*dest++ = *src++));
    return ret;
}

// XXX TODO: Implement strncat

/*
 * Convert a string to a signed long integer.
 *
 * Ignores `locale' stuff.  Assumes that the upper and lower case
 * alphabets and digits are each contiguous.
 */
long strtol(const char *nptr, char **endptr, int base) {
    const char *s = nptr;
    unsigned long acc;
    int c;
    unsigned long cutoff;
    int neg = 0, any, cutlim;

    /*
     * Skip white space and pick up leading +/- sign if any.
     * If base is 0, allow 0x for hex and 0 for octal, else
     * assume decimal; if base is already 16, allow 0x.
     */
    do {
        c = *s++;
    } while (isspace(c));
    
    if (c == '-') {
        neg = 1;
        c = *s++;
    } else if (c == '+') {
        c = *s++; 
    }

    if ((base == 0 || base == 16) && c == '0' && (*s == 'x' || *s == 'X')) {
        c = s[1];
        s += 2;
        base = 16;
    }
    
    if (base == 0) {
        base = c == '0' ? 8 : 10;
    }

    /*
     * Compute the cutoff value between legal numbers and illegal
     * numbers.  That is the largest legal value, divided by the
     * base.  An input number that is greater than this value, if
     * followed by a legal input character, is too big.  One that
     * is equal to this value may be valid or not; the limit
     * between valid and invalid numbers is then based on the last
     * digit.  For instance, if the range for longs is
     * [-2147483648..2147483647] and the input base is 10,
     * cutoff will be set to 214748364 and cutlim to either
     * 7 (neg==0) or 8 (neg==1), meaning that if we have accumulated
     * a value > 214748364, or equal but the next digit is > 7 (or 8),
     * the number is too big, and we will return a range error.
     *
     * Set any if any `digits' consumed; make it negative to indicate
     * overflow.
     */
    cutoff = neg ? -(unsigned long) LONG_MIN : LONG_MAX;
    cutlim = cutoff % (unsigned long) base;
    cutoff /= (unsigned long) base;

    for (acc = 0, any = 0;; c = *s++) {
        if (isdigit(c)) {
            c -= '0';
        } else if (isalpha(c)) {
            c -= isupper(c) ? 'A' - 10 : 'a' - 10;
        } else {
            break;
        }

        if (c >= base) {
            break;
        }
        
        if (any < 0 || acc > cutoff || (acc == cutoff && c > cutlim)) {
            any = -1;
        } else {
            any = 1;
            acc *= base;
            acc += c;
        }
    }

    if (any < 0) {
        // The string is out of range
        acc = neg ? LONG_MIN : LONG_MAX;
    } else if (neg) {
        acc = -acc;
    }
    
    if (endptr != 0) {
        *endptr = (char *)(any ? s - 1 : nptr);
    }

    return acc;
}

/*
 * Finds the first occurrence of value in the first num bytes of ptr.
 */
void* memchr(void* ptr, uint8_t value, size_t num) {
    uint8_t *read = (uint8_t *) ptr;

    for(int i = 0; i < num; i++) {
        if(read[i] == value) return &read[i];
    }

    return NULL;
}

/*
 * Compares the first num bytes in two blocks of memory.
 * Returns 0 if equal, a value greater than 0 if the first byte in ptr1 is
 * greater than the first byte in ptr2; and a value less than zero if the
 * opposite. Note that these comparisons are performed on uint8_t types.
 */
int memcmp(const void* ptr1, const void* ptr2, size_t num) {
    uint8_t *read1 = (uint8_t *) ptr1;
    uint8_t *read2 = (uint8_t *) ptr2;

    for(int i = 0; i < num; i++) {
        if(read1[i] != read2[i]) {
            if(read1[i] > read2[i]) return 1;
            else return -1;
        }
    }

    return 0;
}

/*
 * Fills a given segment of memory with a specified value.
 */
void* memset(void* ptr, uint8_t value, size_t num) {
    // make zero fills faster
    if(unlikely(value == 0x00)) {
        return memclr(ptr, num);
    }

    uint8_t *write = (uint8_t *) ptr;

    for(int i = 0; i < num; i++) {
        write[i] = value;
    }

    return ptr;
}
