#import "VNCClient.h"
#import <CommonCrypto/CommonCryptor.h>
#import <arpa/inet.h>
#import <netdb.h>
#import <sys/socket.h>
#import <unistd.h>
#import <netinet/tcp.h>
#import <errno.h>
#import <dlfcn.h>

static OSStatus iPad1VNCSSLRead(SSLConnectionRef connection, void *data, size_t *dataLength) {
    int s=(int)(intptr_t)connection;
    ssize_t n=recv(s,data,*dataLength,0);
    if(n>0){*dataLength=(size_t)n;return noErr;}
    if(n==0){*dataLength=0;return errSSLClosedGraceful;}
    if(errno==EAGAIN||errno==EWOULDBLOCK||errno==EINTR){*dataLength=0;return errSSLWouldBlock;}
    *dataLength=0;return errSSLClosedAbort;
}
static OSStatus iPad1VNCSSLWrite(SSLConnectionRef connection, const void *data, size_t *dataLength) {
    int s=(int)(intptr_t)connection;
    ssize_t n=send(s,data,*dataLength,0);
    if(n>=0){*dataLength=(size_t)n;return noErr;}
    if(errno==EAGAIN||errno==EWOULDBLOCK||errno==EINTR){*dataLength=0;return errSSLWouldBlock;}
    *dataLength=0;return errSSLClosedAbort;
}
static BOOL recvAllTransport(int s,SSLContextRef ssl,void*buf,size_t len){
    uint8_t*p=(uint8_t*)buf;
    while(len){
        size_t got=0;
        if(ssl){
            OSStatus st=SSLRead(ssl,p,len,&got);
            if(st!=noErr&&st!=errSSLWouldBlock&&st!=errSSLClosedGraceful)return NO;
            if(st==errSSLClosedGraceful&&got==0)return NO;
            if(got==0){usleep(1000);continue;}
        }else{
            ssize_t n=recv(s,p,len,0);if(n<=0)return NO;got=(size_t)n;
        }
        p+=got;len-=got;
    }
    return YES;
}
static BOOL sendAllTransport(int s,SSLContextRef ssl,const void*buf,size_t len){
    const uint8_t*p=(const uint8_t*)buf;
    while(len){
        size_t sent=0;
        if(ssl){
            OSStatus st=SSLWrite(ssl,p,len,&sent);
            if(st!=noErr&&st!=errSSLWouldBlock)return NO;
            if(sent==0){usleep(1000);continue;}
        }else{
            ssize_t n=send(s,p,len,0);if(n<=0)return NO;sent=(size_t)n;
        }
        p+=sent;len-=sent;
    }
    return YES;
}
static uint16_t be16(const uint8_t*p){return(uint16_t)((p[0]<<8)|p[1]);}
static uint32_t be32(const uint8_t*p){return((uint32_t)p[0]<<24)|((uint32_t)p[1]<<16)|((uint32_t)p[2]<<8)|p[3];}
static void p16(uint8_t*p,uint16_t v){p[0]=v>>8;p[1]=v;}
static void p32(uint8_t*p,uint32_t v){p[0]=v>>24;p[1]=v>>16;p[2]=v>>8;p[3]=v;}
static uint8_t rev8(uint8_t b){b=(b&0xF0)>>4|(b&0x0F)<<4;b=(b&0xCC)>>2|(b&0x33)<<2;return(b&0xAA)>>1|(b&0x55)<<1;}


typedef OSStatus (*iPad1VNC_SSLNewContext_Fn)(Boolean, SSLContextRef *);
typedef OSStatus (*iPad1VNC_SSLDisposeContext_Fn)(SSLContextRef);
typedef OSStatus (*iPad1VNC_SSLSetEnableCertVerify_Fn)(SSLContextRef, Boolean);

static iPad1VNC_SSLNewContext_Fn iPad1VNC_SSLNewContextPtr(void) {
    return (iPad1VNC_SSLNewContext_Fn)dlsym(RTLD_DEFAULT,"SSLNewContext");
}
static iPad1VNC_SSLDisposeContext_Fn iPad1VNC_SSLDisposeContextPtr(void) {
    return (iPad1VNC_SSLDisposeContext_Fn)dlsym(RTLD_DEFAULT,"SSLDisposeContext");
}
static iPad1VNC_SSLSetEnableCertVerify_Fn iPad1VNC_SSLSetEnableCertVerifyPtr(void) {
    return (iPad1VNC_SSLSetEnableCertVerify_Fn)dlsym(RTLD_DEFAULT,"SSLSetEnableCertVerify");
}
static void iPad1VNCDisposeSSLContext(SSLContextRef ctx) {
    if(!ctx)return;
    iPad1VNC_SSLDisposeContext_Fn fn=iPad1VNC_SSLDisposeContextPtr();
    if(fn)fn(ctx);
}

@implementation VNCClient
@synthesize delegate=_delegate,qualityProfile=_qualityProfile,adaptiveQualityEnabled=_adaptiveQualityEnabled,preferTight=_preferTight,preferX509TLS=_preferX509TLS;
- (NSUInteger)framebufferWidth{return _fbWidth;}
- (NSUInteger)framebufferHeight{return _fbHeight;}

- (id)initWithHost:(NSString*)host port:(NSInteger)port password:(NSString*)password{
    if((self=[super init])){
        _host=[host copy];_port=port;_password=[password copy];_sock=-1;_writeLock=[[NSLock alloc]init];
        _qualityProfile=VNCQualityBalanced;_serverBytesPerPixel=2;_lastEncoding=[@"RAW" retain];_ssl=NULL;_tlsActive=NO;
        for(int i=0;i<4;i++){memset(&_tightZ[i],0,sizeof(z_stream));_tightZInit[i]=NO;}
    }return self;
}
- (void)resetTightStream:(int)i{
    if(i<0||i>3)return;
    if(_tightZInit[i]){inflateEnd(&_tightZ[i]);memset(&_tightZ[i],0,sizeof(z_stream));_tightZInit[i]=NO;}
}
- (void)dealloc{
    [self disconnect];for(int i=0;i<4;i++)[self resetTightStream:i];
    [_host release];[_password release];[_framebuffer release];[_writeLock release];[_lastEncoding release];[super dealloc];
}
- (void)statusMain:(NSString*)s{if([_delegate respondsToSelector:@selector(vncClientStatus:)])[_delegate vncClientStatus:s];}
- (void)discMain:(NSString*)s{if([_delegate respondsToSelector:@selector(vncClientDisconnected:)])[_delegate vncClientDisconnected:s];}
- (void)frameMain:(UIImage*)i{if([_delegate respondsToSelector:@selector(vncClientFramebuffer:width:height:)])[_delegate vncClientFramebuffer:i width:_fbWidth height:_fbHeight];}
- (void)clipMain:(NSString*)s{if([_delegate respondsToSelector:@selector(vncClientClipboardText:)])[_delegate vncClientClipboardText:s];}

- (void)connect{if(_running)return;_running=YES;[NSThread detachNewThreadSelector:@selector(networkThread) toTarget:self withObject:nil];}
- (void)disconnect{
    _running=NO;
    if(_ssl){SSLClose(_ssl);iPad1VNCDisposeSSLContext(_ssl);_ssl=NULL;_tlsActive=NO;}
    if(_sock>=0){shutdown(_sock,SHUT_RDWR);close(_sock);_sock=-1;}
}

- (BOOL)openSocket{
    struct addrinfo h,*r=NULL,*it;memset(&h,0,sizeof(h));h.ai_family=AF_UNSPEC;h.ai_socktype=SOCK_STREAM;
    char p[16];snprintf(p,sizeof(p),"%ld",(long)_port);if(getaddrinfo([_host UTF8String],p,&h,&r)!=0)return NO;
    for(it=r;it;it=it->ai_next){int s=socket(it->ai_family,it->ai_socktype,it->ai_protocol);if(s<0)continue;int yes=1;setsockopt(s,SOL_SOCKET,SO_KEEPALIVE,&yes,sizeof(yes));setsockopt(s,IPPROTO_TCP,TCP_NODELAY,&yes,sizeof(yes));if(connect(s,it->ai_addr,it->ai_addrlen)==0){_sock=s;break;}close(s);}freeaddrinfo(r);return _sock>=0;
}
- (BOOL)authVNC:(uint8_t*)ch{
    uint8_t key[8]={0};NSData*d=[_password dataUsingEncoding:NSISOLatin1StringEncoding allowLossyConversion:YES];NSUInteger n=MIN((NSUInteger)8,[d length]);if(n)memcpy(key,[d bytes],n);for(int i=0;i<8;i++)key[i]=rev8(key[i]);
    uint8_t out[16];size_t moved=0;return CCCrypt(kCCEncrypt,kCCAlgorithmDES,kCCOptionECBMode,key,8,NULL,ch,16,out,16,&moved)==kCCSuccess&&moved==16&&sendAllTransport(_sock,_ssl,out,16);
}
- (BOOL)sendPixelFormat{
    uint8_t pf[20]={0};pf[6]=0;pf[7]=1;
    // Tight is standardized around true-color and is much more interoperable in 24-bit.
    if(_preferTight||_qualityProfile==VNCQualityQuality){
        pf[4]=32;pf[5]=24;p16(pf+8,255);p16(pf+10,255);p16(pf+12,255);pf[14]=16;pf[15]=8;pf[16]=0;_serverBytesPerPixel=4;
    }else if(_qualityProfile==VNCQualityBalanced){
        pf[4]=16;pf[5]=16;p16(pf+8,31);p16(pf+10,63);p16(pf+12,31);pf[14]=11;pf[15]=5;_serverBytesPerPixel=2;
    }else{
        pf[4]=8;pf[5]=8;p16(pf+8,7);p16(pf+10,7);p16(pf+12,3);pf[14]=5;pf[15]=2;_serverBytesPerPixel=1;
    }
    [_writeLock lock];BOOL ok=sendAllTransport(_sock,_ssl,pf,20);[_writeLock unlock];return ok;
}
- (BOOL)sendEncodings{
    if(_preferTight){
        // Tight, Hextile, RAW, DesktopSize
        uint8_t e[20]={2,0,0,4};p32(e+4,7);p32(e+8,5);p32(e+12,0);p32(e+16,(uint32_t)-223);
        [_writeLock lock];BOOL ok=sendAllTransport(_sock,_ssl,e,20);[_writeLock unlock];return ok;
    }
    uint8_t e[16]={2,0,0,3};p32(e+4,5);p32(e+8,0);p32(e+12,(uint32_t)-223);
    [_writeLock lock];BOOL ok=sendAllTransport(_sock,_ssl,e,16);[_writeLock unlock];return ok;
}
- (BOOL)startX509TLS {
    if(_ssl)return YES;

    iPad1VNC_SSLNewContext_Fn newContext=iPad1VNC_SSLNewContextPtr();
    iPad1VNC_SSLSetEnableCertVerify_Fn setVerify=iPad1VNC_SSLSetEnableCertVerifyPtr();
    if(!newContext||!setVerify){
        [self performSelectorOnMainThread:@selector(statusMain:) withObject:@"X509 TLS unavailable in this iOS SecureTransport" waitUntilDone:NO];
        return NO;
    }

    SSLContextRef ctx=NULL;
    OSStatus st=newContext(false,&ctx);
    if(st!=noErr||!ctx)return NO;

    st=SSLSetIOFuncs(ctx,iPad1VNCSSLRead,iPad1VNCSSLWrite);
    if(st==noErr)st=SSLSetConnection(ctx,(SSLConnectionRef)(intptr_t)_sock);
    if(st==noErr){
        NSData *hn=[_host dataUsingEncoding:NSUTF8StringEncoding];
        if([hn length])st=SSLSetPeerDomainName(ctx,[hn bytes],[hn length]);
    }
    if(st==noErr)st=setVerify(ctx,true);
    if(st!=noErr){iPad1VNCDisposeSSLContext(ctx);return NO;}

    while(_running){
        st=SSLHandshake(ctx);
        if(st==noErr)break;
        if(st==errSSLWouldBlock){usleep(1000);continue;}
        iPad1VNCDisposeSSLContext(ctx);
        return NO;
    }

    _ssl=ctx;
    _tlsActive=YES;
    return YES;
}
- (BOOL)negotiateVeNCryptX509Vnc {
    uint8_t ver[2]={0};
    if(!recvAllTransport(_sock,NULL,ver,2))return NO;
    if(ver[0]!=0||ver[1]<2)return NO;
    uint8_t ours[2]={0,2};
    if(!sendAllTransport(_sock,NULL,ours,2))return NO;
    uint8_t ack=1;
    if(!recvAllTransport(_sock,NULL,&ack,1)||ack!=0)return NO;

    uint8_t count=0;
    if(!recvAllTransport(_sock,NULL,&count,1)||count==0)return NO;
    BOOL hasX509Vnc=NO;
    for(uint8_t i=0;i<count;i++){
        uint8_t b[4];
        if(!recvAllTransport(_sock,NULL,b,4))return NO;
        uint32_t stype=be32(b);
        if(stype==261)hasX509Vnc=YES;
    }
    if(!hasX509Vnc)return NO;

    uint8_t selected[4];p32(selected,261);
    if(!sendAllTransport(_sock,NULL,selected,4))return NO;
    uint8_t subAck=0;
    if(!recvAllTransport(_sock,NULL,&subAck,1)||subAck!=1)return NO;
    if(![self startX509TLS])return NO;

    uint8_t challenge[16];
    if(!recvAllTransport(_sock,_ssl,challenge,16)||![self authVNC:challenge])return NO;
    return YES;
}
- (BOOL)handshake {
    uint8_t v[12];
    if(!recvAllTransport(_sock,NULL,v,12)||memcmp(v,"RFB ",4))return NO;
    if(!sendAllTransport(_sock,NULL,"RFB 003.008\n",12))return NO;

    uint8_t c=0;
    if(!recvAllTransport(_sock,NULL,&c,1)||!c)return NO;
    uint8_t types[255];
    if(!recvAllTransport(_sock,NULL,types,c))return NO;

    uint8_t sel=0;
    BOOL hasVeNCrypt=NO,hasVnc=NO,hasNone=NO;
    for(int i=0;i<c;i++){if(types[i]==19)hasVeNCrypt=YES;else if(types[i]==2)hasVnc=YES;else if(types[i]==1)hasNone=YES;}
    if(_preferX509TLS&&hasVeNCrypt)sel=19;
    else if(hasVnc)sel=2;
    else if(hasNone)sel=1;
    if(!sel||!sendAllTransport(_sock,NULL,&sel,1))return NO;

    if(sel==19){
        if(![self negotiateVeNCryptX509Vnc])return NO;
    }else if(sel==2){
        uint8_t ch[16];
        if(!recvAllTransport(_sock,NULL,ch,16)||![self authVNC:ch])return NO;
    }

    uint8_t result[4];
    if(!recvAllTransport(_sock,_ssl,result,4)||be32(result)!=0)return NO;

    uint8_t shared=1;
    if(!sendAllTransport(_sock,_ssl,&shared,1))return NO;
    uint8_t init[24];
    if(!recvAllTransport(_sock,_ssl,init,24))return NO;
    _fbWidth=be16(init);_fbHeight=be16(init+2);uint32_t nl=be32(init+20);
    if(nl){
        char*name=(char*)malloc(nl);
        BOOL ok=recvAllTransport(_sock,_ssl,name,nl);
        free(name);
        if(!ok)return NO;
    }
    [_framebuffer release];
    _framebuffer=[[NSMutableData alloc]initWithLength:_fbWidth*_fbHeight*4];
    return [self sendPixelFormat]&&[self sendEncodings];
}
- (void)requestUpdate:(BOOL)inc{
    uint8_t m[10]={3,inc?1:0};p16(m+6,(uint16_t)_fbWidth);p16(m+8,(uint16_t)_fbHeight);
    _lastUpdateRequestAt=[NSDate timeIntervalSinceReferenceDate];
    [_writeLock lock];sendAllTransport(_sock,_ssl,m,10);[_writeLock unlock];
}
- (void)pixel:(const uint8_t*)s bgra:(uint8_t*)d{
    uint8_t r=0,g=0,b=0;if(_serverBytesPerPixel==4){b=s[0];g=s[1];r=s[2];}
    else if(_serverBytesPerPixel==2){uint16_t v=s[0]|(s[1]<<8);r=(((v>>11)&31)*255)/31;g=(((v>>5)&63)*255)/63;b=((v&31)*255)/31;}
    else{uint8_t v=s[0];r=(((v>>5)&7)*255)/7;g=(((v>>2)&7)*255)/7;b=((v&3)*255)/3;}d[0]=b;d[1]=g;d[2]=r;d[3]=0;
}
- (void)fillX:(NSUInteger)x y:(NSUInteger)y w:(NSUInteger)w h:(NSUInteger)h c:(uint8_t*)c{
    uint8_t*fb=[_framebuffer mutableBytes];for(NSUInteger yy=0;yy<h&&y+yy<_fbHeight;yy++)for(NSUInteger xx=0;xx<w&&x+xx<_fbWidth;xx++)memcpy(fb+(((y+yy)*_fbWidth+x+xx)*4),c,4);
}
- (BOOL)rawX:(uint16_t)x y:(uint16_t)y w:(uint16_t)w h:(uint16_t)h{
    size_t rb=w*_serverBytesPerPixel;uint8_t*b=malloc(rb);if(!b)return NO;
    for(uint16_t yy=0;yy<h;yy++){if(!recvAllTransport(_sock,_ssl,b,rb)){free(b);return NO;}_statsBytes+=rb;for(uint16_t xx=0;xx<w;xx++){uint8_t c[4];[self pixel:b+xx*_serverBytesPerPixel bgra:c];[self fillX:x+xx y:y+yy w:1 h:1 c:c];}}free(b);return YES;
}
- (BOOL)onePixel:(uint8_t*)c{uint8_t b[4]={0};if(!recvAllTransport(_sock,_ssl,b,_serverBytesPerPixel))return NO;_statsBytes+=_serverBytesPerPixel;[self pixel:b bgra:c];return YES;}
- (BOOL)hextileX:(uint16_t)x y:(uint16_t)y w:(uint16_t)w h:(uint16_t)h {
    uint8_t bg[4]={0}, fg[4]={0};

    for(uint16_t ty=0; ty<h; ty+=16) {
        for(uint16_t tx=0; tx<w; tx+=16) {
            uint16_t tw=MIN((uint16_t)16,(uint16_t)(w-tx));
            uint16_t th=MIN((uint16_t)16,(uint16_t)(h-ty));
            uint8_t s=0;

            if(!recvAllTransport(_sock,_ssl,&s,1)) return NO;
            _statsBytes++;

            if(s & 1) {
                if(![self rawX:x+tx y:y+ty w:tw h:th]) return NO;
                continue;
            }

            if(s & 2) {
                if(![self onePixel:bg]) return NO;
            }
            [self fillX:x+tx y:y+ty w:tw h:th c:bg];

            if(s & 4) {
                if(![self onePixel:fg]) return NO;
            }

            if(s & 8) {
                uint8_t n=0;
                if(!recvAllTransport(_sock,_ssl,&n,1)) return NO;
                _statsBytes++;

                for(uint8_t i=0; i<n; i++) {
                    uint8_t c[4], a[2];
                    uint8_t *use=fg;

                    if(s & 16) {
                        if(![self onePixel:c]) return NO;
                        use=c;
                    }

                    if(!recvAllTransport(_sock,_ssl,a,2)) return NO;
                    _statsBytes+=2;

                    [self fillX:x+tx+(a[0]>>4)
                              y:y+ty+(a[0]&15)
                              w:(a[1]>>4)+1
                              h:(a[1]&15)+1
                              c:use];
                }
            }
        }
    }

    return YES;
}
- (BOOL)compact:(uint32_t*)len{
    uint8_t b;if(!recvAllTransport(_sock,_ssl,&b,1))return NO;_statsBytes++;*len=b&0x7f;if(b&0x80){if(!recvAllTransport(_sock,_ssl,&b,1))return NO;_statsBytes++;*len|=(b&0x7f)<<7;if(b&0x80){if(!recvAllTransport(_sock,_ssl,&b,1))return NO;_statsBytes++;*len|=((uint32_t)b)<<14;}}return YES;
}
- (NSUInteger)tightPixelSize{return(_serverBytesPerPixel==4?3:_serverBytesPerPixel);}
- (void)tightPixel:(const uint8_t*)s bgra:(uint8_t*)d{
    if(_serverBytesPerPixel==4){d[0]=s[0];d[1]=s[1];d[2]=s[2];d[3]=0;}else [self pixel:s bgra:d];
}
- (BOOL)tightInflateStream:(int)s compressed:(NSData*)c expected:(NSUInteger)expected out:(NSMutableData**)out{
    if(!_tightZInit[s]){memset(&_tightZ[s],0,sizeof(z_stream));if(inflateInit(&_tightZ[s])!=Z_OK)return NO;_tightZInit[s]=YES;}
    NSMutableData *o=[NSMutableData dataWithLength:expected];z_stream*z=&_tightZ[s];z->next_in=(Bytef*)[c bytes];z->avail_in=(uInt)[c length];z->next_out=[o mutableBytes];z->avail_out=(uInt)expected;
    while(z->avail_out>0&&z->avail_in>0){int r=inflate(z,Z_SYNC_FLUSH);if(r!=Z_OK&&r!=Z_STREAM_END&&r!=Z_BUF_ERROR)return NO;if(r==Z_STREAM_END)break;if(r==Z_BUF_ERROR&&z->avail_in==0)break;}
    if(z->avail_out!=0)return NO;*out=o;return YES;
}
- (BOOL)tightX:(uint16_t)x y:(uint16_t)y w:(uint16_t)w h:(uint16_t)h{
    uint8_t ctl;if(!recvAllTransport(_sock,_ssl,&ctl,1))return NO;_statsBytes++;
    for(int i=0;i<4;i++)if(ctl&(1<<i))[self resetTightStream:i];
    uint8_t sub=ctl>>4;
    if(sub==8){uint8_t tp[4]={0},c[4];NSUInteger ps=[self tightPixelSize];if(!recvAllTransport(_sock,_ssl,tp,ps))return NO;_statsBytes+=ps;[self tightPixel:tp bgra:c];[self fillX:x y:y w:w h:h c:c];return YES;}
    if(sub==9){uint32_t n;if(![self compact:&n])return NO;NSMutableData*d=[NSMutableData dataWithLength:n];if(!recvAllTransport(_sock,_ssl,[d mutableBytes],n))return NO;_statsBytes+=n;UIImage*i=[UIImage imageWithData:d];if(!i)return NO;
        CGColorSpaceRef cs=CGColorSpaceCreateDeviceRGB();NSMutableData*tmp=[NSMutableData dataWithLength:w*h*4];CGContextRef ctx=CGBitmapContextCreate([tmp mutableBytes],w,h,8,w*4,cs,kCGBitmapByteOrder32Little|kCGImageAlphaNoneSkipFirst);CGContextTranslateCTM(ctx,0,h);CGContextScaleCTM(ctx,1,-1);CGContextDrawImage(ctx,CGRectMake(0,0,w,h),i.CGImage);CGContextRelease(ctx);CGColorSpaceRelease(cs);
        uint8_t*sp=[tmp mutableBytes],*fb=[_framebuffer mutableBytes];for(NSUInteger yy=0;yy<h;yy++)if(x+w<=_fbWidth&&y+yy<_fbHeight)memcpy(fb+(((y+yy)*_fbWidth+x)*4),sp+yy*w*4,w*4);return YES;}
    if(sub>7)return NO;
    int stream=sub&3;BOOL hasFilter=(sub&4)!=0;uint8_t filter=0;if(hasFilter){if(!recvAllTransport(_sock,_ssl,&filter,1))return NO;_statsBytes++;}
    NSUInteger ps=[self tightPixelSize],colors=0,rowBytes=w*ps,expected=rowBytes*h;NSMutableData*palette=nil;
    if(filter==1){uint8_t n;if(!recvAllTransport(_sock,_ssl,&n,1))return NO;_statsBytes++;colors=n+1;palette=[NSMutableData dataWithLength:colors*ps];if(!recvAllTransport(_sock,_ssl,[palette mutableBytes],[palette length]))return NO;_statsBytes+=[palette length];rowBytes=(colors==2?(w+7)/8:w);expected=rowBytes*h;}
    NSMutableData*raw=nil;
    if(expected<12){raw=[NSMutableData dataWithLength:expected];if(!recvAllTransport(_sock,_ssl,[raw mutableBytes],expected))return NO;_statsBytes+=expected;}
    else{uint32_t n;if(![self compact:&n])return NO;NSMutableData*c=[NSMutableData dataWithLength:n];if(!recvAllTransport(_sock,_ssl,[c mutableBytes],n))return NO;_statsBytes+=n;if(![self tightInflateStream:stream compressed:c expected:expected out:&raw])return NO;}
    uint8_t*fb=[_framebuffer mutableBytes];
    if(filter==1){const uint8_t*r=[raw bytes],*pal=[palette bytes];for(NSUInteger yy=0;yy<h;yy++)for(NSUInteger xx=0;xx<w;xx++){NSUInteger idx=(colors==2)?((r[yy*rowBytes+xx/8]>>(7-(xx&7)))&1):r[yy*rowBytes+xx];if(idx>=colors)idx=0;uint8_t c[4];[self tightPixel:pal+idx*ps bgra:c];if(x+xx<_fbWidth&&y+yy<_fbHeight)memcpy(fb+(((y+yy)*_fbWidth+x+xx)*4),c,4);}}
    else if(filter==2){
        // Gradient. Tight is forced to 24-bit when enabled, therefore ps==3 here.
        if(ps!=3)return NO;const uint8_t*r=[raw bytes];NSMutableData*prev=[NSMutableData dataWithLength:w*3];NSMutableData*cur=[NSMutableData dataWithLength:w*3];
        for(NSUInteger yy=0;yy<h;yy++){uint8_t*pr=[prev mutableBytes],*cr=[cur mutableBytes];for(NSUInteger xx=0;xx<w;xx++)for(int ch=0;ch<3;ch++){int left=(xx?cr[(xx-1)*3+ch]:0),up=(yy?pr[xx*3+ch]:0),ul=(yy&&xx?pr[(xx-1)*3+ch]:0);int est=left+up-ul;if(est<0)est=0;if(est>255)est=255;cr[xx*3+ch]=(uint8_t)((est+r[(yy*w+xx)*3+ch])&255);}for(NSUInteger xx=0;xx<w;xx++){uint8_t c[4];[self tightPixel:cr+xx*3 bgra:c];if(x+xx<_fbWidth&&y+yy<_fbHeight)memcpy(fb+(((y+yy)*_fbWidth+x+xx)*4),c,4);}[prev setData:cur];}
    }else{
        const uint8_t*r=[raw bytes];for(NSUInteger yy=0;yy<h;yy++)for(NSUInteger xx=0;xx<w;xx++){uint8_t c[4];[self tightPixel:r+(yy*w+xx)*ps bgra:c];if(x+xx<_fbWidth&&y+yy<_fbHeight)memcpy(fb+(((y+yy)*_fbWidth+x+xx)*4),c,4);}
    }return YES;
}
- (UIImage*)image{
    CGColorSpaceRef cs=CGColorSpaceCreateDeviceRGB();CGDataProviderRef pr=CGDataProviderCreateWithCFData((CFDataRef)_framebuffer);CGImageRef cg=CGImageCreate(_fbWidth,_fbHeight,8,32,_fbWidth*4,cs,kCGBitmapByteOrder32Little|kCGImageAlphaNoneSkipFirst,pr,NULL,false,kCGRenderingIntentDefault);UIImage*i=[UIImage imageWithCGImage:cg];CGImageRelease(cg);CGDataProviderRelease(pr);CGColorSpaceRelease(cs);return i;
}
- (void)publishStats {
    NSTimeInterval now=[NSDate timeIntervalSinceReferenceDate];
    NSTimeInterval e=now-_statsStart;
    if(e<0.50)return;

    CGFloat fps=(e>0?((CGFloat)_statsFrames/(CGFloat)e):0);
    CGFloat kbps=(e>0?((CGFloat)_statsBytes*8.0/1000.0/(CGFloat)e):0);
    _fpsSamples++;
    _fpsAverage+=((fps-_fpsAverage)/(CGFloat)_fpsSamples);

    NSString*q=(_qualityProfile==0?@"Fast":(_qualityProfile==1?@"Balanced":@"Quality"));
    if([_delegate respondsToSelector:@selector(vncClientStatsFPS:avgFPS:kbps:latency:avgLatency:maxLatency:encoding:quality:uptime:totalFrames:)])
        [_delegate vncClientStatsFPS:fps
                             avgFPS:_fpsAverage
                               kbps:kbps
                            latency:_latencyEMA*1000.0
                         avgLatency:_latencyAverage*1000.0
                         maxLatency:_latencyMax*1000.0
                           encoding:_lastEncoding
                            quality:q
                             uptime:now-_connectedAt
                        totalFrames:_totalFrames];

    _statsStart=now;
    _statsFrames=0;
    _statsBytes=0;
}
- (void)adapt:(NSTimeInterval)decode{
    if(!_adaptiveQualityEnabled||_preferTight)return;NSTimeInterval now=[NSDate timeIntervalSinceReferenceDate];if(now-_lastQualityChange<10)return;
    BOOL bad=(decode>.22||_latencyEMA>.20);BOOL good=(decode<.075&&_latencyEMA>0&&_latencyEMA<.09);
    if(bad){_slowFrames++;_fastFrames=0;}else if(good){_fastFrames++;if(_slowFrames)_slowFrames--;}else{if(_slowFrames)_slowFrames--;if(_fastFrames)_fastFrames--;}
    VNCQualityProfile n=_qualityProfile;if(_slowFrames>=3&&n>0){n--;_slowFrames=0;}else if(_fastFrames>=15&&n<2){n++;_fastFrames=0;}
    if(n!=_qualityProfile){_qualityProfile=n;_lastQualityChange=now;[self sendPixelFormat];[self requestUpdate:NO];NSString*q=(n==0?@"Fast":(n==1?@"Balanced":@"Quality"));[self performSelectorOnMainThread:@selector(statusMain:) withObject:[NSString stringWithFormat:@"Auto: %@",q] waitUntilDone:NO];}
}
- (BOOL)frameUpdate{
    NSTimeInterval now=[NSDate timeIntervalSinceReferenceDate];
    if(_lastUpdateRequestAt>0){
        CGFloat rtt=now-_lastUpdateRequestAt;
        _latencyEMA=(_latencyEMA<=0?rtt:_latencyEMA*.72+rtt*.28);
        _latencySamples++;
        _latencyAverage+=((rtt-_latencyAverage)/(CGFloat)_latencySamples);
        if(rtt>_latencyMax)_latencyMax=rtt;
    }
    NSTimeInterval st=now;uint8_t h[3];if(!recvAllTransport(_sock,_ssl,h,3))return NO;uint16_t nr=be16(h+1);
    for(uint16_t i=0;i<nr;i++){uint8_t r[12];if(!recvAllTransport(_sock,_ssl,r,12))return NO;uint16_t x=be16(r),y=be16(r+2),w=be16(r+4),hh=be16(r+6);int32_t enc=(int32_t)be32(r+8);
        [_lastEncoding release];_lastEncoding=[(enc==7?@"Tight":(enc==5?@"Hextile":(enc==0?@"RAW":@"Other"))) retain];
        if(enc==0){if(![self rawX:x y:y w:w h:hh])return NO;}else if(enc==5){if(![self hextileX:x y:y w:w h:hh])return NO;}else if(enc==7){if(![self tightX:x y:y w:w h:hh])return NO;}
        else if(enc==-223){_fbWidth=w;_fbHeight=hh;[_framebuffer release];_framebuffer=[[NSMutableData alloc]initWithLength:_fbWidth*_fbHeight*4];}else return NO;
    }
    UIImage*i=[self image];if(i)[self performSelectorOnMainThread:@selector(frameMain:) withObject:i waitUntilDone:NO];_statsFrames++;_totalFrames++;[self publishStats];[self adapt:[NSDate timeIntervalSinceReferenceDate]-st];return YES;
}
- (void)networkThread{
    NSAutoreleasePool*p=[[NSAutoreleasePool alloc]init];[self performSelectorOnMainThread:@selector(statusMain:) withObject:@"Connecting…" waitUntilDone:NO];
    if(![self openSocket]||![self handshake]){[self disconnect];[self performSelectorOnMainThread:@selector(discMain:) withObject:@"Connection/authentication failed" waitUntilDone:NO];[p drain];return;}
    _connectedAt=_statsStart=[NSDate timeIntervalSinceReferenceDate];_latencyEMA=0;_latencyAverage=0;_latencyMax=0;_latencySamples=0;_fpsAverage=0;_fpsSamples=0;_totalFrames=0;_totalBytes=0;[self performSelectorOnMainThread:@selector(statusMain:) withObject:@"Connected" waitUntilDone:NO];[self requestUpdate:NO];
    while(_running){
        NSAutoreleasePool *iterationPool=[[NSAutoreleasePool alloc] init];
        uint8_t t=0;BOOL keep=recvAllTransport(_sock,_ssl,&t,1);
        if(keep&&t==0){keep=[self frameUpdate];if(keep)[self requestUpdate:YES];}
        else if(keep&&t==2){uint8_t pad=0;keep=recvAllTransport(_sock,_ssl,&pad,1);}
        else if(keep&&t==3){
            uint8_t h[7];keep=recvAllTransport(_sock,_ssl,h,7);
            if(keep){
                uint32_t n=be32(h+3);char*b=(char*)malloc(n+1);
                keep=(b!=NULL)&&recvAllTransport(_sock,_ssl,b,n);
                if(keep){b[n]=0;NSString*s=[[[NSString alloc]initWithBytes:b length:n encoding:NSUTF8StringEncoding]autorelease];if(s)[self performSelectorOnMainThread:@selector(clipMain:) withObject:s waitUntilDone:NO];}
                if(b)free(b);
            }
        }else if(keep){keep=NO;}
        [iterationPool drain];
        if(!keep)break;
    }
    [self disconnect];[self performSelectorOnMainThread:@selector(discMain:) withObject:@"Disconnected" waitUntilDone:NO];[p drain];
}
- (void)sendPointerX:(NSUInteger)x y:(NSUInteger)y buttons:(uint8_t)b{if(!_running||_sock<0)return;uint8_t m[6]={5,b};p16(m+2,MIN(x,65535));p16(m+4,MIN(y,65535));[_writeLock lock];sendAllTransport(_sock,_ssl,m,6);[_writeLock unlock];}
- (void)sendKeySym:(uint32_t)k down:(BOOL)d{if(!_running||_sock<0)return;uint8_t m[8]={4,d?1:0};p32(m+4,k);[_writeLock lock];sendAllTransport(_sock,_ssl,m,8);[_writeLock unlock];}
- (void)sendClipboardText:(NSString*)s{if(!_running||_sock<0||![s length])return;NSData*d=[s dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];NSUInteger n=MIN([d length],(NSUInteger)(1024*1024));NSMutableData*m=[NSMutableData dataWithLength:8+n];uint8_t*p=[m mutableBytes];p[0]=6;p32(p+4,n);memcpy(p+8,[d bytes],n);[_writeLock lock];sendAllTransport(_sock,_ssl,[m bytes],[m length]);[_writeLock unlock];}
@end
