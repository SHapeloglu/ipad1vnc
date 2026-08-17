#import <Foundation/Foundation.h>

@interface LegacyTerminalBuffer : NSObject {
    NSUInteger _cols,_rows,_x,_y;
    NSMutableArray *_lines;
    NSMutableArray *_scrollback;
    NSMutableString *_escape;
    BOOL _inEscape;
}
@property(nonatomic, readonly) NSUInteger columns;
@property(nonatomic, readonly) NSUInteger rows;
- (id)initWithColumns:(NSUInteger)cols rows:(NSUInteger)rows;
- (void)reset;
- (void)appendTerminalText:(NSString *)text;
- (NSString *)renderString;
- (void)trimScrollbackTo:(NSUInteger)lines;
@end
