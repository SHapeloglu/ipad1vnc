#import "LegacyTerminalBuffer.h"

@implementation LegacyTerminalBuffer
- (NSUInteger)columns{return _cols;}
- (NSUInteger)rows{return _rows;}

- (id)initWithColumns:(NSUInteger)cols rows:(NSUInteger)rows {
    if((self=[super init])){_cols=MAX(40,cols);_rows=MAX(12,rows);_lines=[[NSMutableArray alloc]init];_scrollback=[[NSMutableArray alloc]init];_escape=[[NSMutableString alloc]init];[self reset];}
    return self;
}
- (void)dealloc{[_lines release];[_scrollback release];[_escape release];[super dealloc];}
- (NSMutableString *)blankLine {
    NSMutableString *s=[NSMutableString stringWithCapacity:_cols];
    for(NSUInteger i=0;i<_cols;i++)[s appendString:@" "];
    return s;
}
- (void)reset {
    [_lines removeAllObjects];[_scrollback removeAllObjects];
    for(NSUInteger i=0;i<_rows;i++)[_lines addObject:[self blankLine]];
    _x=0;_y=0;_inEscape=NO;[_escape setString:@""];
}
- (void)scroll {
    if([_lines count]){
        NSString *old=[[_lines objectAtIndex:0] copy];
        [_scrollback addObject:old];[old release];
        if([_scrollback count]>5000)[_scrollback removeObjectAtIndex:0];
        [_lines removeObjectAtIndex:0];[_lines addObject:[self blankLine]];
    }
    if(_y)_y--;
}
- (void)put:(unichar)c {
    if(_x>=_cols){_x=0;_y++;} if(_y>=_rows)[self scroll];
    NSMutableString *line=[_lines objectAtIndex:_y];
    [line replaceCharactersInRange:NSMakeRange(_x,1) withString:[NSString stringWithCharacters:&c length:1]];
    _x++; if(_x>=_cols){_x=0;_y++;if(_y>=_rows)[self scroll];}
}
- (NSArray *)paramsFromCSI:(NSString *)s {
    if([s length]<2)return [NSArray array];
    NSString *core=[s substringWithRange:NSMakeRange(1,[s length]-2)];
    if(![core length])return [NSArray arrayWithObject:[NSNumber numberWithInt:0]];
    NSArray *parts=[core componentsSeparatedByString:@";"];NSMutableArray *a=[NSMutableArray array];
    for(NSString *p in parts)[a addObject:[NSNumber numberWithInteger:([p length]?[p integerValue]:0)]];
    return a;
}
- (void)handleEscape:(NSString *)seq {
    if(![seq hasPrefix:@"["]||[seq length]<2)return;
    unichar final=[seq characterAtIndex:[seq length]-1];NSArray *p=[self paramsFromCSI:seq];
    NSInteger a=([p count]?[[p objectAtIndex:0] integerValue]:0);if(a<=0)a=1;
    if(final=='A'){_y=(_y>(NSUInteger)a?_y-a:0);}
    else if(final=='B'){_y=MIN(_rows-1,_y+(NSUInteger)a);}
    else if(final=='C'){_x=MIN(_cols-1,_x+(NSUInteger)a);}
    else if(final=='D'){_x=(_x>(NSUInteger)a?_x-a:0);}
    else if(final=='H'||final=='f'){
        NSInteger row=([p count]>0?[[p objectAtIndex:0] integerValue]:1);
        NSInteger col=([p count]>1?[[p objectAtIndex:1] integerValue]:1);
        _y=MIN(_rows-1,(NSUInteger)MAX(1,row)-1);_x=MIN(_cols-1,(NSUInteger)MAX(1,col)-1);
    } else if(final=='J'){
        if(a==2||a==3){for(NSUInteger i=0;i<_rows;i++)[_lines replaceObjectAtIndex:i withObject:[self blankLine]];_x=_y=0;}
    } else if(final=='K'){
        NSMutableString *line=[_lines objectAtIndex:_y];
        NSUInteger start=(a==1?0:_x),end=(a==1?_x:_cols);
        if(a==2){start=0;end=_cols;}
        for(NSUInteger i=start;i<end&&i<_cols;i++)[line replaceCharactersInRange:NSMakeRange(i,1) withString:@" "];
    }
    // SGR (m), private modes and most xterm decoration are intentionally ignored.
}
- (void)appendTerminalText:(NSString *)text {
    for(NSUInteger i=0;i<[text length];i++){
        unichar c=[text characterAtIndex:i];
        if(_inEscape){
            [_escape appendFormat:@"%C",c];
            if((c>='A'&&c<='Z')||(c>='a'&&c<='z')||c=='~'){
                [self handleEscape:_escape];[_escape setString:@""];_inEscape=NO;
            } else if([_escape length]>64){[_escape setString:@""];_inEscape=NO;}
            continue;
        }
        if(c==0x1b){_inEscape=YES;[_escape setString:@""];continue;}
        if(c=='\r'){_x=0;continue;}
        if(c=='\n'){_y++;if(_y>=_rows)[self scroll];continue;}
        if(c=='\b'){if(_x)_x--;continue;}
        if(c=='\t'){NSUInteger next=MIN(_cols-1,((_x/8)+1)*8);while(_x<next)[self put:' '];continue;}
        if(c>=32)[self put:c];
    }
}
- (NSString *)renderString {
    NSMutableString *s=[NSMutableString string];
    NSUInteger sb=[_scrollback count],start=(sb>200?sb-200:0);
    for(NSUInteger i=start;i<sb;i++)[s appendFormat:@"%@\n",[[_scrollback objectAtIndex:i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
    for(NSUInteger i=0;i<[_lines count];i++){
        NSString *line=[_lines objectAtIndex:i];
        [s appendString:[line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
        if(i+1<[_lines count])[s appendString:@"\n"];
    }
    return s;
}
- (void)trimScrollbackTo:(NSUInteger)lines {
    while([_scrollback count]>lines)[_scrollback removeObjectAtIndex:0];
}
@end
