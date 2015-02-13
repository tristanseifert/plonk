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
                    // XXX: implement signed ints
                    int arg = va_arg(vl, int);
                    char *buf = itoa(arg, 10);
                    int size = (int) strlen(buf);

                    int j;
                    // XXX: Make sure we don't go over n when copying.
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
