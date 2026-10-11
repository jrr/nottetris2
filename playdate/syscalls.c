// Stubs for the system calls newlib's stdio wants on the device, where there's no OS beneath it.
// Chipmunk's assertions print, which pulls them in; nothing here is ever expected to run.
#include <sys/stat.h>

int _close( int fd ) { (void)fd; return -1; }
int _fstat( int fd, struct stat* st ) { (void)fd; st->st_mode = S_IFCHR; return 0; }
int _isatty( int fd ) { (void)fd; return 1; }
int _lseek( int fd, int offset, int whence ) { (void)fd; (void)offset; (void)whence; return 0; }
int _read( int fd, char* buf, int len ) { (void)fd; (void)buf; (void)len; return 0; }
int _write( int fd, const char* buf, int len ) { (void)fd; (void)buf; return len; }
int _getpid( void ) { return 1; }
int _kill( int pid, int sig ) { (void)pid; (void)sig; return -1; }
void _exit( int status ) { (void)status; for ( ;; ) { } }
