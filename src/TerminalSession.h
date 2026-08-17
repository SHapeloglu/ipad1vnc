#import <Foundation/Foundation.h>
@protocol TerminalSessionDelegate <NSObject>
- (void)terminalSessionOutput:(NSString *)text;
- (void)terminalSessionEnded:(NSString *)reason;
@end
@interface TerminalSession : NSObject {
    id<TerminalSessionDelegate> _delegate; int _masterFD; pid_t _pid; BOOL _running;
}
@property(nonatomic,assign) id<TerminalSessionDelegate> delegate;
@property(nonatomic,readonly) BOOL running;
- (BOOL)startSSHHost:(NSString*)host port:(NSInteger)port user:(NSString*)user keyPath:(NSString*)keyPath command:(NSString*)command;
- (BOOL)startTunnelHost:(NSString*)host port:(NSInteger)sshPort user:(NSString*)user keyPath:(NSString*)keyPath localPort:(NSInteger)localPort remoteHost:(NSString*)remoteHost remotePort:(NSInteger)remotePort;
- (BOOL)generateRSAKeyAtPath:(NSString*)path;
- (void)sendText:(NSString*)text;
- (void)stop;
@end
