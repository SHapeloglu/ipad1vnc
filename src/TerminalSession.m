#import "TerminalSession.h"
#import <sys/types.h>
#import <sys/ioctl.h>
#import <sys/wait.h>
#import <sys/stat.h>
#import <fcntl.h>
#import <unistd.h>
#import <signal.h>
#import <termios.h>
#import <errno.h>
#import <stdlib.h>

@implementation TerminalSession
@synthesize delegate=_delegate;
- (BOOL)running{return _running;}

- (id)init { if((self=[super init])){_masterFD=-1;_pid=-1;_running=NO;} return self; }
- (void)dealloc { [self stop]; [super dealloc]; }

- (void)deliver:(NSString*)s {
    if([_delegate respondsToSelector:@selector(terminalSessionOutput:)])
        [_delegate terminalSessionOutput:s];
}
- (void)ended:(NSString*)s {
    if([_delegate respondsToSelector:@selector(terminalSessionEnded:)])
        [_delegate terminalSessionEnded:s];
}
- (void)readLoop {
    NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];
    char buf[2048];
    while(_running && _masterFD>=0){
        ssize_t n=read(_masterFD,buf,sizeof(buf));
        if(n>0){
            NSString *s=[[[NSString alloc] initWithBytes:buf length:(NSUInteger)n encoding:NSUTF8StringEncoding] autorelease];
            if(!s) s=[[[NSString alloc] initWithBytes:buf length:(NSUInteger)n encoding:NSISOLatin1StringEncoding] autorelease];
            if(s) [self performSelectorOnMainThread:@selector(deliver:) withObject:s waitUntilDone:NO];
        } else break;
    }
    _running=NO;
    [self performSelectorOnMainThread:@selector(ended:) withObject:@"SSH session ended" waitUntilDone:NO];
    [pool drain];
}

- (BOOL)spawnSSHArguments:(NSArray*)args {
    if(_running) [self stop];

    int master=posix_openpt(O_RDWR|O_NOCTTY);
    if(master<0) return NO;
    if(grantpt(master)!=0 || unlockpt(master)!=0){close(master);return NO;}
    char *slaveName=ptsname(master);
    if(!slaveName){close(master);return NO;}

    pid_t pid=fork();
    if(pid<0){close(master);return NO;}
    if(pid==0){
        setsid();
        int slave=open(slaveName,O_RDWR);
        if(slave<0)_exit(126);
#ifdef TIOCSCTTY
        ioctl(slave,TIOCSCTTY,0);
#endif
        dup2(slave,STDIN_FILENO);dup2(slave,STDOUT_FILENO);dup2(slave,STDERR_FILENO);
        if(slave>STDERR_FILENO)close(slave);
        close(master);

        NSUInteger c=[args count];
        char **argv=(char**)calloc(c+2,sizeof(char*));
        argv[0]=strdup("/usr/bin/ssh");
        for(NSUInteger i=0;i<c;i++)argv[i+1]=strdup([[args objectAtIndex:i] UTF8String]);
        argv[c+1]=NULL;
        execv("/usr/bin/ssh",argv);
        _exit(127);
    }

    _pid=pid;_masterFD=master;_running=YES;
    [NSThread detachNewThreadSelector:@selector(readLoop) toTarget:self withObject:nil];
    return YES;
}

- (BOOL)startSSHHost:(NSString*)host port:(NSInteger)port user:(NSString*)user keyPath:(NSString*)keyPath command:(NSString*)command {
    if(![[NSFileManager defaultManager] isExecutableFileAtPath:@"/usr/bin/ssh"]){
        [self deliver:@"ERROR: /usr/bin/ssh not found. Install OpenSSH client on the jailbroken iPad.\n"];
        return NO;
    }
    NSMutableArray *a=[NSMutableArray array];
    [a addObject:@"-tt"]; [a addObject:@"-p"]; [a addObject:[NSString stringWithFormat:@"%ld",(long)port]];
    [a addObject:@"-o"]; [a addObject:@"ServerAliveInterval=30"];
    [a addObject:@"-o"]; [a addObject:@"ServerAliveCountMax=3"];
    [a addObject:@"-o"]; [a addObject:@"StrictHostKeyChecking=ask"];
    [a addObject:@"-o"]; [a addObject:@"UserKnownHostsFile=/var/mobile/.ssh/known_hosts"];
    if([keyPath length]){[a addObject:@"-i"];[a addObject:keyPath];}
    if(![user length]){
        [self deliver:@"ERROR: SSH username is required.\n"];
        return NO;
    }
    NSString *target=[NSString stringWithFormat:@"%@@%@",user,host];
    [a addObject:target];
    if([command length])[a addObject:command];
    return [self spawnSSHArguments:a];
}

- (BOOL)startTunnelHost:(NSString*)host port:(NSInteger)sshPort user:(NSString*)user keyPath:(NSString*)keyPath localPort:(NSInteger)localPort remoteHost:(NSString*)remoteHost remotePort:(NSInteger)remotePort {
    if(![keyPath length]){
        [self deliver:@"SSH tunnel requires a key file in this beta (password automation is intentionally disabled).\n"];
        return NO;
    }
    if(![user length]){
        [self deliver:@"SSH tunnel requires an SSH username.\n"];
        return NO;
    }
    NSMutableArray *a=[NSMutableArray arrayWithObjects:@"-N",@"-p",[NSString stringWithFormat:@"%ld",(long)sshPort],
                       @"-o",@"ExitOnForwardFailure=yes",@"-o",@"ServerAliveInterval=30",@"-o",@"ServerAliveCountMax=3",
                       @"-o",@"StrictHostKeyChecking=yes",@"-o",@"UserKnownHostsFile=/var/mobile/.ssh/known_hosts",
                       @"-i",keyPath,
                       @"-L",[NSString stringWithFormat:@"%ld:%@:%ld",(long)localPort,remoteHost,(long)remotePort],
                       ([user length]?[NSString stringWithFormat:@"%@@%@",user,host]:host),nil];
    return [self spawnSSHArguments:a];
}
- (BOOL)generateRSAKeyAtPath:(NSString*)path {
    if(![path length]||![[NSFileManager defaultManager] isExecutableFileAtPath:@"/usr/bin/ssh-keygen"])return NO;
    NSString *dir=[path stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedLong:0700] forKey:NSFilePosixPermissions] error:nil];
    pid_t p=fork();if(p<0)return NO;if(p==0){execl("/usr/bin/ssh-keygen","ssh-keygen","-t","rsa","-b","2048","-N","","-f",[path UTF8String],(char*)NULL);_exit(127);}
    int status=0;waitpid(p,&status,0);if(WIFEXITED(status)&&WEXITSTATUS(status)==0){chmod([path fileSystemRepresentation],0600);return YES;}return NO;
}
- (void)sendText:(NSString*)text { if(!_running||_masterFD<0||![text length])return;NSData*d=[text dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];write(_masterFD,[d bytes],[d length]);}
- (void)stop {
    _running=NO;
    if(_pid>0){kill(_pid,SIGTERM);waitpid(_pid,NULL,WNOHANG);_pid=-1;}
    if(_masterFD>=0){close(_masterFD);_masterFD=-1;}
}
@end
