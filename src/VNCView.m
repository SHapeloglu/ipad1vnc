#import "VNCView.h"
#import "VNCClient.h"

@implementation VNCView
@synthesize image = _image;
@synthesize client = _client;
@synthesize pointerSensitivity = _pointerSensitivity;
@synthesize inputMode = _inputMode;
@synthesize precisionMode = _precisionMode;
@synthesize dragLock = _dragLock;

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor blackColor];
        self.multipleTouchEnabled = YES;
        _zoomScale = 1.0;
        _pinchStartScale = 1.0;
        _scrollAccumulator = 0.0;
        _pointerSensitivity = 1.0;
        _inputMode = VNCInputModeDirect;
        _trackpadMoved = NO;
        _precisionMode = NO;
        _dragLock = NO;
        _dragging = NO;

        UILongPressGestureRecognizer *longPress = [[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)] autorelease];
        longPress.minimumPressDuration = 0.55;
        [self addGestureRecognizer:longPress];

        UIPinchGestureRecognizer *pinch = [[[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinch:)] autorelease];
        pinch.cancelsTouchesInView = YES;
        [self addGestureRecognizer:pinch];

        UIPanGestureRecognizer *scroll = [[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(twoFingerScroll:)] autorelease];
        scroll.minimumNumberOfTouches = 2;
        scroll.maximumNumberOfTouches = 2;
        scroll.cancelsTouchesInView = YES;
        [self addGestureRecognizer:scroll];

        UITapGestureRecognizer *middleTap=[[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(middleTap:)] autorelease];
        middleTap.numberOfTouchesRequired=3;middleTap.numberOfTapsRequired=1;middleTap.cancelsTouchesInView=YES;
        [self addGestureRecognizer:middleTap];

        UITapGestureRecognizer *dragTap=[[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dragTap:)] autorelease];
        dragTap.numberOfTouchesRequired=1;dragTap.numberOfTapsRequired=2;dragTap.cancelsTouchesInView=YES;
        [self addGestureRecognizer:dragTap];
    }
    return self;
}

- (void)dealloc { [_image release]; [super dealloc]; }
- (void)updateImage:(UIImage *)image { self.image=image; [self setNeedsDisplay]; }

- (CGRect)imageRect {
    if (!_image) return self.bounds;
    CGSize is=_image.size, bs=self.bounds.size;
    CGFloat fit=MIN(bs.width/is.width,bs.height/is.height);
    CGFloat scale=fit*_zoomScale;
    CGSize ds=CGSizeMake(is.width*scale,is.height*scale);
    return CGRectMake((bs.width-ds.width)/2.0,(bs.height-ds.height)/2.0,ds.width,ds.height);
}
- (void)drawRect:(CGRect)rect { (void)rect; if(_image)[_image drawInRect:[self imageRect]]; }

- (CGPoint)remotePointForViewPoint:(CGPoint)p {
    CGRect r=[self imageRect];
    if(r.size.width<=0||r.size.height<=0||!_client)return CGPointZero;
    CGFloat rx=(p.x-r.origin.x)/r.size.width, ry=(p.y-r.origin.y)/r.size.height;
    rx=MIN(1,MAX(0,rx)); ry=MIN(1,MAX(0,ry));
    return CGPointMake(rx*MAX(1,_client.framebufferWidth-1),ry*MAX(1,_client.framebufferHeight-1));
}
- (CGPoint)remotePointForTouch:(UITouch *)touch { return [self remotePointForViewPoint:[touch locationInView:self]]; }

- (void)ensureTrackpadPointer {
    if(!_client)return;
    if(_lastPoint.x<0||_lastPoint.y<0||_lastPoint.x>=_client.framebufferWidth||_lastPoint.y>=_client.framebufferHeight)
        _lastPoint=CGPointMake(_client.framebufferWidth/2.0,_client.framebufferHeight/2.0);
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if([[event allTouches] count]!=1)return;
    UITouch *t=[touches anyObject];
    if(_inputMode==VNCInputModeTrackpad){
        [self ensureTrackpadPointer];
        _lastTouchViewPoint=[t locationInView:self];
        _trackpadMoved=NO;
        return;
    }
    _lastPoint=[self remotePointForTouch:t];
    [_client sendPointerX:(NSUInteger)_lastPoint.x y:(NSUInteger)_lastPoint.y buttons:1];
}
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    if([[event allTouches] count]!=1)return;
    UITouch *t=[touches anyObject];
    CGFloat speed=MIN(1.5,MAX(0.5,_pointerSensitivity));if(_precisionMode)speed*=0.30;
    if(_inputMode==VNCInputModeTrackpad){
        CGPoint p=[t locationInView:self];
        CGFloat dx=p.x-_lastTouchViewPoint.x, dy=p.y-_lastTouchViewPoint.y;
        if(fabs(dx)>1.0||fabs(dy)>1.0)_trackpadMoved=YES;
        _lastTouchViewPoint=p;
        CGRect ir=[self imageRect];
        CGFloat sx=(_client.framebufferWidth/MAX(ir.size.width,1.0))*speed;
        CGFloat sy=(_client.framebufferHeight/MAX(ir.size.height,1.0))*speed;
        _lastPoint.x+=dx*sx; _lastPoint.y+=dy*sy;
        _lastPoint.x=MIN(MAX(_lastPoint.x,0),MAX(1,_client.framebufferWidth-1));
        _lastPoint.y=MIN(MAX(_lastPoint.y,0),MAX(1,_client.framebufferHeight-1));
        [_client sendPointerX:(NSUInteger)_lastPoint.x y:(NSUInteger)_lastPoint.y buttons:(_dragging?1:0)];
        return;
    }
    CGPoint target=[self remotePointForTouch:t];
    _lastPoint=CGPointMake(_lastPoint.x+(target.x-_lastPoint.x)*speed,_lastPoint.y+(target.y-_lastPoint.y)*speed);
    _lastPoint.x=MIN(MAX(_lastPoint.x,0),MAX(1,_client.framebufferWidth-1));
    _lastPoint.y=MIN(MAX(_lastPoint.y,0),MAX(1,_client.framebufferHeight-1));
    [_client sendPointerX:(NSUInteger)_lastPoint.x y:(NSUInteger)_lastPoint.y buttons:1];
}
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if([[event allTouches] count]>1)return;
    if(_inputMode==VNCInputModeTrackpad){
        if(!_trackpadMoved){
            if(_dragLock){_dragging=!_dragging;[_client sendPointerX:(NSUInteger)_lastPoint.x y:(NSUInteger)_lastPoint.y buttons:(_dragging?1:0)];}
            else{[_client sendPointerX:(NSUInteger)_lastPoint.x y:(NSUInteger)_lastPoint.y buttons:1];[_client sendPointerX:(NSUInteger)_lastPoint.x y:(NSUInteger)_lastPoint.y buttons:0];}
        }
        return;
    }
    UITouch *t=[touches anyObject]; _lastPoint=[self remotePointForTouch:t];
    [_client sendPointerX:(NSUInteger)_lastPoint.x y:(NSUInteger)_lastPoint.y buttons:0];
}
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    (void)touches;(void)event;
    [_client sendPointerX:(NSUInteger)_lastPoint.x y:(NSUInteger)_lastPoint.y buttons:0];
}

- (void)longPress:(UILongPressGestureRecognizer *)g {
    if(!_client)return;
    CGPoint rp;
    if(_inputMode==VNCInputModeTrackpad){ [self ensureTrackpadPointer]; rp=_lastPoint; }
    else {
        CGPoint p=[g locationInView:self]; CGRect r=[self imageRect];
        if(!CGRectContainsPoint(r,p))return;
        rp=[self remotePointForViewPoint:p]; _lastPoint=rp;
    }
    if(g.state==UIGestureRecognizerStateBegan)[_client sendPointerX:(NSUInteger)rp.x y:(NSUInteger)rp.y buttons:4];
    else if(g.state==UIGestureRecognizerStateEnded||g.state==UIGestureRecognizerStateCancelled)
        [_client sendPointerX:(NSUInteger)rp.x y:(NSUInteger)rp.y buttons:0];
}
- (void)pinch:(UIPinchGestureRecognizer *)g {
    if(g.state==UIGestureRecognizerStateBegan)_pinchStartScale=_zoomScale;
    if(g.state==UIGestureRecognizerStateBegan||g.state==UIGestureRecognizerStateChanged){
        _zoomScale=MIN(2.5,MAX(1.0,_pinchStartScale*g.scale)); [self setNeedsDisplay];
    }
}
- (void)twoFingerScroll:(UIPanGestureRecognizer *)g {
    if(!_client)return;
    CGPoint p=[g locationInView:self], rp=(_inputMode==VNCInputModeTrackpad?_lastPoint:[self remotePointForViewPoint:p]);
    if(_inputMode==VNCInputModeTrackpad)[self ensureTrackpadPointer]; else _lastPoint=rp;
    if(g.state==UIGestureRecognizerStateBegan){_scrollAccumulator=0;[g setTranslation:CGPointZero inView:self];return;}
    if(g.state!=UIGestureRecognizerStateChanged)return;
    CGPoint tr=[g translationInView:self];_scrollAccumulator+=tr.y;[g setTranslation:CGPointZero inView:self];
    const CGFloat step=24.0;
    while(_scrollAccumulator>=step){[_client sendPointerX:(NSUInteger)rp.x y:(NSUInteger)rp.y buttons:16];[_client sendPointerX:(NSUInteger)rp.x y:(NSUInteger)rp.y buttons:0];_scrollAccumulator-=step;}
    while(_scrollAccumulator<=-step){[_client sendPointerX:(NSUInteger)rp.x y:(NSUInteger)rp.y buttons:8];[_client sendPointerX:(NSUInteger)rp.x y:(NSUInteger)rp.y buttons:0];_scrollAccumulator+=step;}
}

- (void)middleTap:(UITapGestureRecognizer*)g {
    if(g.state!=UIGestureRecognizerStateRecognized||!_client)return;
    CGPoint rp=(_inputMode==VNCInputModeTrackpad?_lastPoint:[self remotePointForViewPoint:[g locationInView:self]]);
    if(_inputMode==VNCInputModeTrackpad)[self ensureTrackpadPointer];
    [_client sendPointerX:(NSUInteger)rp.x y:(NSUInteger)rp.y buttons:2];
    [_client sendPointerX:(NSUInteger)rp.x y:(NSUInteger)rp.y buttons:0];
}
- (void)dragTap:(UITapGestureRecognizer*)g {
    if(g.state!=UIGestureRecognizerStateRecognized||!_client||!_dragLock)return;
    CGPoint rp=(_inputMode==VNCInputModeTrackpad?_lastPoint:[self remotePointForViewPoint:[g locationInView:self]]);
    if(_inputMode==VNCInputModeTrackpad)[self ensureTrackpadPointer];
    _dragging=!_dragging;
    _lastPoint=rp;
    [_client sendPointerX:(NSUInteger)rp.x y:(NSUInteger)rp.y buttons:(_dragging?1:0)];
}
@end
