#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <zlib.h>
#import <Security/SecureTransport.h>

typedef enum {
    VNCQualityFast = 0,
    VNCQualityBalanced = 1,
    VNCQualityQuality = 2
} VNCQualityProfile;

@protocol VNCClientDelegate <NSObject>
- (void)vncClientStatus:(NSString *)status;
- (void)vncClientFramebuffer:(UIImage *)image width:(NSUInteger)width height:(NSUInteger)height;
- (void)vncClientDisconnected:(NSString *)reason;
@optional
- (void)vncClientClipboardText:(NSString *)text;
- (void)vncClientStatsFPS:(CGFloat)fps avgFPS:(CGFloat)avgFPS kbps:(CGFloat)kbps latency:(CGFloat)latency avgLatency:(CGFloat)avgLatency maxLatency:(CGFloat)maxLatency encoding:(NSString *)encoding quality:(NSString *)quality uptime:(NSTimeInterval)uptime totalFrames:(unsigned long long)totalFrames;
@end

@interface VNCClient : NSObject {
    NSString *_host;
    NSInteger _port;
    NSString *_password;
    id<VNCClientDelegate> _delegate;
    int _sock;
    BOOL _running;
    NSUInteger _fbWidth,_fbHeight;
    NSMutableData *_framebuffer;
    NSLock *_writeLock;
    VNCQualityProfile _qualityProfile;
    NSUInteger _serverBytesPerPixel;
    BOOL _adaptiveQualityEnabled;
    BOOL _preferTight;
    BOOL _preferX509TLS;
    SSLContextRef _ssl;
    BOOL _tlsActive;
    NSUInteger _slowFrames,_fastFrames;
    NSTimeInterval _lastQualityChange;

    NSTimeInterval _statsStart,_connectedAt,_lastUpdateRequestAt;
    NSUInteger _statsFrames;
    unsigned long long _statsBytes;
    unsigned long long _totalFrames;
    unsigned long long _totalBytes;
    CGFloat _latencyEMA;
    CGFloat _latencyAverage;
    CGFloat _latencyMax;
    unsigned long long _latencySamples;
    CGFloat _fpsAverage;
    unsigned long long _fpsSamples;
    NSString *_lastEncoding;

    z_stream _tightZ[4];
    BOOL _tightZInit[4];
}
@property(nonatomic,assign) id<VNCClientDelegate> delegate;
@property(nonatomic,readonly) NSUInteger framebufferWidth;
@property(nonatomic,readonly) NSUInteger framebufferHeight;
@property(nonatomic,assign) VNCQualityProfile qualityProfile;
@property(nonatomic,assign) BOOL adaptiveQualityEnabled;
@property(nonatomic,assign) BOOL preferTight;
@property(nonatomic,assign) BOOL preferX509TLS;
- (id)initWithHost:(NSString *)host port:(NSInteger)port password:(NSString *)password;
- (void)connect;
- (void)disconnect;
- (void)sendPointerX:(NSUInteger)x y:(NSUInteger)y buttons:(uint8_t)buttons;
- (void)sendKeySym:(uint32_t)keysym down:(BOOL)down;
- (void)sendClipboardText:(NSString *)text;
@end
