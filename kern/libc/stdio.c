// XXX: roll our own self-hosted stdarg
#include <stdarg.h>

#include "stdio.h"
#include "stdbool.h"
#include "stdlib.h"
#include "string.h"

int snprintf(char *s, size_t n, const char *format, ...) {
    const char *current = format;
    char c;

    va_list vl;
    va_start(vl, format);

    // varible to know if we're at a placeholder
    bool control = false;

    int i = 0;
    while((c = *current++) != 0 && i < (int) n) {
        
        if(control == true) {
            control = false;
            
            // switch on the format thing
            switch(c) {
                case '%':
                    s[i++] = c;
                    break;
                case 'd': {
                    int arg = va_arg(vl, int);

                    // Support for signed ints
                    if(arg < 0) {
                        arg = (arg ^ -1) + 1;
                        s[i++] = arg;
                    }

                    char *buf = itoa(arg, 10);
                    int size = (int) strlen(buf);

                    int j;

                    if(size + i < (int) n) // Make sure we dont overflow the buf.
                        size = (int) n;

                    for(j = 0; j < size; j++) {
                        s[i++] = buf[j];
                    }

                    break;
                } default:
                    // XXX: implement everything else
                    break;
            }

        } else if(c == '%') {
            control = true;

        } else {
            s[i++] = c;
        }
    }

    return 0;

}
