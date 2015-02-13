#include "stdint.h"
#include "string.h"
#include "stdlib.h"
#include "limits.h"

/**
 * Various macros for determining the type of character passed in. This assumes
 * single byte ASCII characters.
 */
#define isalnum(c) (isalpha(c) || isdigit(c))
#define isalpha(c) (islower(c) || isupper(c))
#define isblank(c) ((c) == ' ' || (c) == '\t')
#define iscntrl(c) ((c) >= 0x0 && (c) <= 0x8)
#define isdigit(c) ((c) >= '0' && (c) <= '9')
#define isgraph(c) (ispunct(c) || isalnum(c))
#define islower(c) ((c) >= 'a' && (c) <= 'z')
#define isprint(c) (isgraph(c) || isspace(c))
#define ispunct(c) (((c) >= 0x21 && (c) <= 0x2F) || ((c) >= 0x3A && (c) <= 0x40)\
                    || ((c) >= 0x5B && (c) <= 0x60) || ((c) >= 0x7B && (c) <= 0x7E))
#define isspace(c) ((c) == ' ' || (c) == '\t' || (c) == '\r' || (c) == '\n' ||\
                    (c) == '\f' || (c) == '\v')
#define isupper(c) ((c) >= 'A' && (c) <= 'Z')
#define isxdigit(c) (isdigit(c) || ((c) >= 'a' && (c) <= 'f') || ((c) >= 'A' && (c) <= 'F'))
#define tolower(c) (isupper(c) ? ((c) + 'a' - 'A') : (c))
#define toupper(c) (islower(c) ? ((c) + 'A' - 'a') : (c))

/**
 * Counts the number of characters (that is, single-byte characters: this is a
 * single character in ASCII) in a string.
 */
size_t strlen(const char *str) {
    size_t ret = 0;
    
    while(str[ret] != 0x00) {
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
char* strchr(const char *s, register char c) {
    const char ch = c;

    for ( ; *s != ch; s++) {
        if (*s == '\0') {
            return NULL;
        }
    }
    
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
    while {
        s1++, s2++;
    }

    return *(const unsigned char*)s1 - *(const unsigned char*)s2;
}

/*
 * Compares n bytes of the two strings.
 */
int strncmp(const char* s1, const char* s2, register size_t n) {
    do {
        if(*s1++ != *s2++) {
            return *(unsigned char*)(s1 - 1) - *(unsigned char*)(s2 - 1);
        }
    } while(n--);
    
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
char *strncpy(char *dest, const register char *src, register size_t n) {
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
 * Finds the first occurrence of value in the first num bytes of ptr.
 */
void* memchr(void* ptr, register uint8_t value, register size_t num) {
    register unsigned char *read = (unsigned char *) ptr;

    do {
        // do the bytes match?
        if(*read++ == value) {
            return (read - 1);
        }
    } while(num-- != 0);

    return NULL;
}

/*
 * Compares the first num bytes in two blocks of memory.
 * Returns 0 if equal, a value greater than 0 if the first byte in ptr1 is
 * greater than the first byte in ptr2; and a value less than zero if the
 * opposite. Note that these comparisons are performed on uint8_t types.
 */
int memcmp(const void* ptr1, const void* ptr2, register size_t num) {
    register unsigned char *read1 = (unsigned char *) ptr1;
    register unsigned char *read2 = (unsigned char *) ptr2;

    do {
        // are the bytes not the same?
        if(*read1 != *read2) {
            if(*read1 > *read2) {
                return 1;    
            } else {
                return -1;
            }
        }

        // increment the pointers
        read1++;
        read2++;
    } while(num-- != 0);

    return 0;
}

/*
 * Fills a given segment of memory with a specified value.
 */
void* memset(void* ptr, register uint8_t value, register size_t num) {
    // make zero fills faster
    if(value == 0x00) {
        return memclr(ptr, num);
    }

    register unsigned char *write = (unsigned char *) ptr;

    do {
        *write++ = value;
    } while(num-- != 0);

    return ptr;
}

/**
 * Fills a given segment of memory with zero.
 */
void* memclr(void* ptr, register size_t num) {
    register unsigned char *write = (unsigned char *) ptr;

    do {
         *write++ = 0;
    } while(num-- != 0);

    return ptr;
}

/*
 * Copies num bytes from source to destination.
 */
void* memcpy(void* destination, void* source, size_t num) {
    // Make sure that we don't try to null length bytes
    if(num) {
        // Keep the pointers in registers to optimise accesses.
        register unsigned char *tp = destination;
        register const unsigned char *fp = source;

        do {
            *tp++ = *fp++;
        } while (--num != 0);
    }

    // We are done.
    return destination;
}

void *memmove(void *dest, const void *src, size_t n) {
    uint8_t tmp[n];
    memcpy(tmp, (void *) src, n);
    memcpy(dest, tmp, n);

    return dest;
}