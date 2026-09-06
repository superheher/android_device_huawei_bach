#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <linux/falloc.h>

#define R(name, expr) do { errno=0; long _r=(long)(expr); \
  printf("  %-26s %s%s%s\n", name, _r<0?"FAIL  errno=":"OK", _r<0?strerror(errno):"", ""); } while(0)

int main(int argc,char**argv){
  if(argc<2){fprintf(stderr,"usage: probe <dir>\n");return 2;}
  char p[512],p2[512]; snprintf(p,sizeof p,"%s/probe.bin",argv[1]);
  snprintf(p2,sizeof p2,"%s/probe.renamed",argv[1]);
  printf("dir: %s\n",argv[1]);
  int fd=open(p,O_RDWR|O_CREAT|O_TRUNC,0600);
  if(fd<0){printf("  open: FAIL %s\n",strerror(errno));return 1;}
  R("ftruncate 4MB",      ftruncate(fd,4*1024*1024));
  R("fallocate",          fallocate(fd,0,0,4*1024*1024));
  R("fallocate KEEP_SIZE",fallocate(fd,FALLOC_FL_KEEP_SIZE,0,4*1024*1024));
  R("pwrite",             pwrite(fd,"x",1,1024));
  R("fsync",              fsync(fd));
  R("fdatasync",          fdatasync(fd));
  /* the SQLite WAL primitive: shared writable mapping */
  errno=0; void*m=mmap(NULL,65536,PROT_READ|PROT_WRITE,MAP_SHARED,fd,0);
  if(m==MAP_FAILED) printf("  %-26s FAIL  errno=%s\n","mmap MAP_SHARED RW",strerror(errno));
  else { memset(m,0xAB,65536);
         printf("  %-26s OK\n","mmap MAP_SHARED RW");
         R("msync(MS_SYNC)", msync(m,65536,MS_SYNC));
         R("munmap", munmap(m,65536)); }
  errno=0; void*mp=mmap(NULL,65536,PROT_READ,MAP_PRIVATE,fd,0);
  printf("  %-26s %s\n","mmap MAP_PRIVATE RO", mp==MAP_FAILED?strerror(errno):"OK");
  if(mp!=MAP_FAILED) munmap(mp,65536);
  R("flock LOCK_EX",      flock(fd,2));
  R("fcntl F_SETLK",      ({struct flock fl={0}; fl.l_type=F_WRLCK; fl.l_whence=SEEK_SET; fcntl(fd,F_SETLK,&fl);}));
  close(fd);
  R("rename",             rename(p,p2));
  char lp[512]; snprintf(lp,sizeof lp,"%s/probe.hardlink",argv[1]);
  R("link (hardlink)",    link(p2,lp));
  errno=0; int dfd=open(p2,O_RDONLY|O_DIRECT);
  printf("  %-26s %s\n","open O_DIRECT", dfd<0?strerror(errno):"OK");
  if(dfd>=0) close(dfd);
  unlink(lp); unlink(p2); unlink(p);
  return 0;
}
