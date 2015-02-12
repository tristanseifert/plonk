// XXX: roll our own self-hosted stdarg
#include <stdarg.h>

#include "stdio.h"
#include "stdbool.h"
#include "num.h"

int snprintf(char *s, size_t n, const char *format, ...) {

    const char *current = format;
    char c;

    va_list vl;
    va_start(vl, format);

    // varible to know if we're at a placeholder
    bool control = false;

    int i;
    for(i = 0; i < (int) n; i++) {
        c = *current++;
        
        if(control == true) {
            control = false;
            
            // switch on the format thing
            switch(c) {
                case '%':
                    s[i] = c;
                    break;
                case 'd': {
                    // XXX: implement signed ints
                    int arg = va_arg(vl, int);
                    s[i] = itoa(arg, 10);
                    break;
                } default:
                    // XXX: implement everything else
                    break;
            }

        } else if(c == '%') {
            control = true;

        } else {
            s[i] = c;
        }
    }

    return 0;

}
