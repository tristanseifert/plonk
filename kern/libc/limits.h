#ifndef LIMITS_H
#define LIMITS_H

#define CHAR_BIT    8                           /* number of bits in a char */

#define SCHAR_MAX   0x7f                        /* max value for signed char */
#define SCHAR_MIN   (-SCHAR_MAX-1)              /* min value for signed char */
#define UCHAR_MAX   0xff                        /* max value for unsigned char */

#define USHRT_MAX   0xffff                      /* max value for unsigned short*/
#define SHRT_MAX    0x7fff                      /* max value for short */
#define SHRT_MIN    (-SHRT_MAX-1)               /* min value for short */

#define UINT_MAX    0xffffffff                  /* max unsigned int */
#define INT_MAX     0x7fffffff                  /* max signed int */
#define INT_MIN     (-INT_MAX-1)                /* min signed int */

#if __LP64__
#define ULONG_MAX   0xffffffffffffffffUL        /* max unsigned long */
#define LONG_MAX    0x7fffffffffffffffL         /* max signed long */
#define LONG_MIN    (-LONG_MAX-1)               /* min signed long */

#else /* !__LP64__ */

#define ULONG_MAX   0xffffffffUL                /* max unsigned long */
#define LONG_MAX    0x7fffffffL                 /* max signed long */
#define LONG_MIN    (-0x7fffffffL-1)            /* min signed long */

#endif /* __LP64__ */
#endif /* LIMITS_H */
