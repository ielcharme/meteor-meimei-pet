#import <Cocoa/Cocoa.h>
#import <math.h>

typedef NS_ENUM(NSInteger, MMPetMode) {
    MMPetModeIdle,
    MMPetModeWalkRight,
    MMPetModeWalkLeft,
    MMPetModeWave,
    MMPetModeJump,
    MMPetModePlay,
    MMPetModeReview
};

typedef struct {
    NSInteger row;
    NSInteger frames;
    double fps;
} MMAnimation;

static MMAnimation MMAnimationForMode(MMPetMode mode) {
    switch (mode) {
        case MMPetModeIdle:      return (MMAnimation){0, 6, 2.0};
        case MMPetModeWalkRight: return (MMAnimation){1, 8, 5.2};
        case MMPetModeWalkLeft:  return (MMAnimation){1, 8, 5.2};
        case MMPetModeWave:      return (MMAnimation){3, 4, 2.3};
        case MMPetModeJump:      return (MMAnimation){4, 5, 3.0};
        case MMPetModePlay:      return (MMAnimation){7, 6, 2.1};
        case MMPetModeReview:    return (MMAnimation){8, 6, 1.8};
    }
}

static CGFloat MMRandom(CGFloat minimum, CGFloat maximum) {
    CGFloat unit = (CGFloat)arc4random() / (CGFloat)UINT32_MAX;
    return minimum + (maximum - minimum) * unit;
}

static CGFloat MMCurrentCodexPetWidth(void) {
    const CGFloat fallbackWidth = 97.0;
    NSString *configPath = [NSHomeDirectory() stringByAppendingPathComponent:@".codex/config.toml"];
    NSString *config = [NSString stringWithContentsOfFile:configPath encoding:NSUTF8StringEncoding error:nil];
    if (!config) return fallbackWidth;

    for (NSString *line in [config componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (![trimmed hasPrefix:@"avatar-overlay-mascot-width-px"]) continue;
        NSArray<NSString *> *parts = [trimmed componentsSeparatedByString:@"="];
        if (parts.count < 2) break;
        CGFloat width = [parts.lastObject stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].doubleValue;
        if (width >= 80.0 && width <= 224.0) return width;
        break;
    }
    return fallbackWidth;
}

static NSArray<NSString *> *MMColdJokes(void) {
    static NSArray<NSString *> *jokes;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        jokes = @[
            @"什么动物最容易摔倒？狐狸，因为它脚滑。",
            @"什么门永远关不上？球门。",
            @"什么布剪不断？瀑布。",
            @"为什么数学书总皱眉？因为它有太多问题。",
            @"冰箱为什么很有礼貌？开门总先亮灯。",
            @"铅笔累了会去哪？去削息一下。",
            @"什么东西越洗越脏？水。",
            @"哪一种狗最会保密？沉默是金毛。",
            @"哪个字人人见了都会念错？错。",
            @"为什么电脑爱打喷嚏？因为它中了病毒。",
            @"云为什么不去上班？因为它总想飘走。",
            @"水杯为什么很开心？因为你终于想起它了。",
            @"边牧为什么不迷路？妹妹会看代码，也会看路。",
            @"今天的冷笑话有多冷？妹妹的鼻尖都起雾啦。"
        ];
    });
    return jokes;
}

@interface MMPetView : NSView
@property(nonatomic, strong) NSImage *atlas;
@property(nonatomic) NSInteger row;
@property(nonatomic) NSInteger column;
@property(nonatomic) BOOL flippedHorizontally;
@property(nonatomic, copy) void (^onClick)(void);
@property(nonatomic, copy) void (^onDrag)(NSPoint point);
@property(nonatomic, copy) void (^onDragEnd)(void);
@property(nonatomic, copy) void (^onHover)(void);
@property(nonatomic, strong) NSTrackingArea *hoverTrackingArea;
@property(nonatomic) BOOL didDrag;
@end

@implementation MMPetView

- (instancetype)initWithFrame:(NSRect)frame atlas:(NSImage *)atlas {
    self = [super initWithFrame:frame];
    if (self) {
        _atlas = atlas;
        self.wantsLayer = YES;
        self.layer.backgroundColor = NSColor.clearColor.CGColor;
    }
    return self;
}

- (BOOL)acceptsFirstResponder { return YES; }
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    if (self.hoverTrackingArea) [self removeTrackingArea:self.hoverTrackingArea];
    self.hoverTrackingArea = [[NSTrackingArea alloc]
        initWithRect:NSZeroRect
             options:NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways | NSTrackingInVisibleRect
               owner:self
            userInfo:nil];
    [self addTrackingArea:self.hoverTrackingArea];
}

- (void)mouseEntered:(NSEvent *)event {
    if (self.onHover) self.onHover();
}

- (void)setRow:(NSInteger)row {
    _row = row;
    self.needsDisplay = YES;
}

- (void)setColumn:(NSInteger)column {
    _column = column;
    self.needsDisplay = YES;
}

- (void)setFlippedHorizontally:(BOOL)flippedHorizontally {
    _flippedHorizontally = flippedHorizontally;
    self.needsDisplay = YES;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    if (self.atlas.size.width < 1536 || self.atlas.size.height < 2288) return;

    [[NSColor clearColor] setFill];
    NSRectFillUsingOperation(self.bounds, NSCompositingOperationCopy);
    NSGraphicsContext.currentContext.imageInterpolation = NSImageInterpolationHigh;
    CGFloat cellWidth = 192;
    CGFloat cellHeight = 208;
    CGFloat sourceY = self.atlas.size.height - ((CGFloat)self.row + 1) * cellHeight;
    NSRect source = NSMakeRect((CGFloat)self.column * cellWidth, sourceY, cellWidth, cellHeight);
    [NSGraphicsContext saveGraphicsState];
    if (self.flippedHorizontally) {
        NSAffineTransform *flip = [NSAffineTransform transform];
        [flip translateXBy:NSWidth(self.bounds) yBy:0];
        [flip scaleXBy:-1 yBy:1];
        [flip concat];
    }
    [self.atlas drawInRect:self.bounds
                  fromRect:source
                 operation:NSCompositingOperationSourceOver
                  fraction:1.0
            respectFlipped:NO
                     hints:nil];
    [NSGraphicsContext restoreGraphicsState];
}

- (void)mouseDown:(NSEvent *)event {
    self.didDrag = NO;
}

- (void)mouseDragged:(NSEvent *)event {
    self.didDrag = YES;
    if (self.onDrag) self.onDrag(NSEvent.mouseLocation);
}

- (void)mouseUp:(NSEvent *)event {
    if (self.didDrag) {
        if (self.onDragEnd) self.onDragEnd();
    } else if (self.onClick) {
        self.onClick();
    }
    self.didDrag = NO;
}

@end

@interface MMPetPanel : NSPanel
@end

@implementation MMPetPanel
- (BOOL)canBecomeKeyWindow { return NO; }
- (BOOL)canBecomeMainWindow { return NO; }
@end

@interface MMBubbleView : NSView
@property(nonatomic, copy) NSString *message;
@end

@implementation MMBubbleView

- (BOOL)isFlipped { return YES; }

- (void)setMessage:(NSString *)message {
    _message = [message copy];
    self.needsDisplay = YES;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    NSRect body = NSInsetRect(NSMakeRect(1, 1, NSWidth(self.bounds) - 2, NSHeight(self.bounds) - 12), 1, 1);
    NSBezierPath *bubble = [NSBezierPath bezierPathWithRoundedRect:body xRadius:14 yRadius:14];
    [[NSColor colorWithWhite:1 alpha:0.96] setFill];
    [bubble fill];
    [[NSColor colorWithWhite:0 alpha:0.14] setStroke];
    bubble.lineWidth = 1;
    [bubble stroke];

    CGFloat centerX = NSMidX(self.bounds);
    NSBezierPath *tail = [NSBezierPath bezierPath];
    [tail moveToPoint:NSMakePoint(centerX - 8, NSMaxY(body) - 1)];
    [tail lineToPoint:NSMakePoint(centerX, NSMaxY(self.bounds) - 1)];
    [tail lineToPoint:NSMakePoint(centerX + 8, NSMaxY(body) - 1)];
    [tail closePath];
    [[NSColor colorWithWhite:1 alpha:0.96] setFill];
    [tail fill];

    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
    paragraph.alignment = NSTextAlignmentCenter;
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:13 weight:NSFontWeightMedium],
        NSForegroundColorAttributeName: [NSColor colorWithWhite:0.12 alpha:1],
        NSParagraphStyleAttributeName: paragraph
    };
    NSRect textRect = NSInsetRect(body, 12, 9);
    [self.message ?: @"" drawInRect:textRect withAttributes:attributes];
}

@end

@interface MMPetController : NSObject
@property(nonatomic, strong) MMPetPanel *panel;
@property(nonatomic, strong) MMPetView *petView;
@property(nonatomic, strong) MMPetPanel *bubblePanel;
@property(nonatomic, strong) MMBubbleView *bubbleView;
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic) NSTimeInterval lastTick;
@property(nonatomic) NSTimeInterval nextJokeAt;
@property(nonatomic) NSTimeInterval bubbleHideAt;
@property(nonatomic) MMPetMode mode;
@property(nonatomic) double animationElapsed;
@property(nonatomic) double behaviorRemaining;
@property(nonatomic, strong) NSNumber *targetX;
@property(nonatomic) CGFloat baseY;
@property(nonatomic) NSSize petSize;
@property(nonatomic) CGFloat dropVelocity;
@property(nonatomic) CGFloat edgeEmergenceStartX;
@property(nonatomic) NSInteger parkedEdge;
@property(nonatomic) NSTimeInterval lastInteractionAt;
@property(nonatomic) NSTimeInterval edgeEmergenceElapsed;
@property(nonatomic) BOOL paused;
@property(nonatomic) BOOL petHidden;
@property(nonatomic) BOOL dragging;
@property(nonatomic) BOOL liftedDuringDrag;
@property(nonatomic) BOOL dropping;
@property(nonatomic) BOOL edgeRetreating;
@property(nonatomic) BOOL edgeHidden;
@property(nonatomic) BOOL edgeEmerging;
@property(nonatomic, copy) void (^onPauseChanged)(BOOL paused);
@property(nonatomic, copy) void (^onVisibilityChanged)(BOOL hidden);
- (instancetype)initWithAtlas:(NSImage *)atlas;
- (void)togglePause;
- (void)toggleVisibility;
- (void)playNow;
- (void)bringToMouse;
- (void)tellJokeNow;
- (void)hoverReveal;
- (void)dragFinished;
@end

@implementation MMPetController

static const CGFloat MMBubbleWidth = 236;
static const CGFloat MMBubbleHeight = 78;
static const NSTimeInterval MMJokeDisplayDuration = 8.0;
static const NSTimeInterval MMCornerHideDelay = 5.0 * 60.0;
static const CGFloat MMWalkSpeed = 42.0;
static const CGFloat MMEdgeHideSpeed = 30.0;
static const CGFloat MMEdgePeekWidth = 24.0;
static const CGFloat MMEdgeEmergenceHopHeight = 28.0;
static const NSTimeInterval MMEdgeEmergenceDuration = 0.82;
static const double MMJumpDuration = 1.8;

- (instancetype)initWithAtlas:(NSImage *)atlas {
    self = [super init];
    if (self) {
        CGFloat petWidth = MMCurrentCodexPetWidth();
        _petSize = NSMakeSize(petWidth, petWidth * 208.0 / 192.0);
        NSRect frame = NSMakeRect(0, 0, _petSize.width, _petSize.height);
        _panel = [[MMPetPanel alloc] initWithContentRect:frame
                                              styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
        _petView = [[MMPetView alloc] initWithFrame:frame atlas:atlas];
        _panel.contentView = _petView;
        _panel.opaque = NO;
        _panel.backgroundColor = NSColor.clearColor;
        _panel.hasShadow = NO;
        _panel.level = NSFloatingWindowLevel;
        _panel.ignoresMouseEvents = NO;
        _panel.hidesOnDeactivate = NO;
        _panel.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary;

        NSRect bubbleFrame = NSMakeRect(0, 0, MMBubbleWidth, MMBubbleHeight);
        _bubblePanel = [[MMPetPanel alloc] initWithContentRect:bubbleFrame
                                                    styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO];
        _bubbleView = [[MMBubbleView alloc] initWithFrame:bubbleFrame];
        _bubblePanel.contentView = _bubbleView;
        _bubblePanel.opaque = NO;
        _bubblePanel.backgroundColor = NSColor.clearColor;
        _bubblePanel.hasShadow = YES;
        _bubblePanel.level = NSFloatingWindowLevel;
        _bubblePanel.ignoresMouseEvents = YES;
        _bubblePanel.hidesOnDeactivate = NO;
        _bubblePanel.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary;

        __weak typeof(self) weakSelf = self;
        _petView.onClick = ^{ [weakSelf playNow]; };
        _petView.onDrag = ^(NSPoint point) { [weakSelf dragTo:point]; };
        _petView.onDragEnd = ^{ [weakSelf dragFinished]; };
        _petView.onHover = ^{ [weakSelf hoverReveal]; };

        [self placeNearMouse];
        [_panel orderFrontRegardless];
        [self enterMode:MMPetModeIdle duration:1.2];
        _lastTick = NSProcessInfo.processInfo.systemUptime;
        _lastInteractionAt = _lastTick;
        [self scheduleNextJokeFrom:_lastTick];
        _timer = [NSTimer timerWithTimeInterval:1.0 / 30.0
                                        target:self
                                      selector:@selector(tick:)
                                      userInfo:nil
                                       repeats:YES];
        [NSRunLoop.mainRunLoop addTimer:_timer forMode:NSRunLoopCommonModes];
    }
    return self;
}

- (void)dealloc { [self.timer invalidate]; }

- (void)togglePause {
    self.paused = !self.paused;
    if (self.paused) {
        [self enterMode:MMPetModeIdle duration:DBL_MAX];
        [self hideBubble];
    }
    else [self chooseNextBehavior:NO];
    if (self.onPauseChanged) self.onPauseChanged(self.paused);
}

- (void)toggleVisibility {
    self.petHidden = !self.petHidden;
    if (self.petHidden) {
        [self.panel orderOut:nil];
        [self hideBubble];
    } else {
        [self clearEdgeStateAndReveal];
        [self placeNearMouse];
        [self.panel orderFrontRegardless];
        [self enterMode:MMPetModeWave duration:2.4];
    }
    if (self.onVisibilityChanged) self.onVisibilityChanged(self.petHidden);
}

- (void)playNow {
    if (self.petHidden) return;
    [self noteInteraction];
    [self clearEdgeStateAndReveal];
    self.paused = NO;
    if (self.onPauseChanged) self.onPauseChanged(NO);
    uint32_t choice = arc4random_uniform(3);
    MMPetMode next = choice == 0 ? MMPetModeWave : (choice == 1 ? MMPetModeJump : MMPetModePlay);
    double duration = next == MMPetModeJump ? MMJumpDuration : (next == MMPetModeWave ? 2.4 : 3.2);
    [self enterMode:next duration:duration];
}

- (void)bringToMouse {
    self.petHidden = NO;
    [self noteInteraction];
    [self clearEdgeStateAndReveal];
    if (self.onVisibilityChanged) self.onVisibilityChanged(NO);
    [self placeNearMouse];
    [self.panel orderFrontRegardless];
    [self enterMode:MMPetModeWave duration:2.4];
}

- (void)tellJokeNow {
    if (self.petHidden || self.edgeHidden || self.edgeRetreating || self.edgeEmerging) [self bringToMouse];
    [self noteInteraction];
    [self showRandomJoke];
}

- (void)hoverReveal {
    if (self.petHidden || (!self.edgeHidden && !self.edgeRetreating)) return;
    [self noteInteraction];
    self.paused = NO;
    self.edgeEmerging = YES;
    self.edgeHidden = NO;
    self.edgeRetreating = NO;
    self.edgeEmergenceElapsed = 0;
    self.edgeEmergenceStartX = self.panel.frame.origin.x;
    self.animationElapsed = 0;
    self.petView.row = 4;
    self.petView.column = 0;
    self.petView.flippedHorizontally = NO;
    if (self.onPauseChanged) self.onPauseChanged(NO);
}

- (void)tick:(NSTimer *)timer {
    NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    NSTimeInterval delta = MIN(now - self.lastTick, 0.1);
    self.lastTick = now;
    if (self.bubblePanel.visible && now >= self.bubbleHideAt) [self hideBubble];
    if (self.paused || self.petHidden) return;
    if (now >= self.nextJokeAt) [self showRandomJoke];
    if (self.dragging) return;

    if (self.dropping) {
        [self updateDrop:delta];
        [self updateBubblePosition];
        return;
    }

    if (self.edgeEmerging) {
        [self updateEdgeEmergence:delta];
        [self updateBubblePosition];
        return;
    }

    if (self.edgeHidden) return;

    self.animationElapsed += delta;
    self.behaviorRemaining -= delta;
    [self applyAnimationFrame];

    if (self.edgeRetreating) {
        [self updateEdgeRetreat:delta];
        [self updateBubblePosition];
        return;
    }

    if (self.parkedEdge != 0) {
        if (now - self.lastInteractionAt >= MMCornerHideDelay) [self beginEdgeRetreat];
        [self updateBubblePosition];
        return;
    }

    switch (self.mode) {
        case MMPetModeWalkRight:
        case MMPetModeWalkLeft:
            [self updateWalking:delta];
            break;
        case MMPetModeJump:
            [self updateJump];
            break;
        default:
            [self.panel setFrameOrigin:NSMakePoint(self.panel.frame.origin.x, self.baseY)];
            break;
    }
    [self updateBubblePosition];
    if (self.behaviorRemaining <= 0) [self chooseNextBehavior:NO];
}

- (void)updateWalking:(NSTimeInterval)delta {
    NSScreen *screen = [self currentScreen];
    if (!screen || !self.targetX) {
        [self chooseNextBehavior:NO];
        return;
    }
    CGFloat direction = self.mode == MMPetModeWalkRight ? 1 : -1;
    CGFloat x = self.panel.frame.origin.x + direction * MMWalkSpeed * delta;
    CGFloat minX = NSMinX(screen.visibleFrame);
    CGFloat maxX = NSMaxX(screen.visibleFrame) - self.petSize.width;
    x = MIN(MAX(x, minX), maxX);
    x = round(x * screen.backingScaleFactor) / screen.backingScaleFactor;
    [self.panel setFrameOrigin:NSMakePoint(x, self.baseY)];

    CGFloat destination = self.targetX.doubleValue;
    if ((direction > 0 && x >= destination) || (direction < 0 && x <= destination)) {
        [self chooseNextBehavior:YES];
    }
}

- (void)updateJump {
    double progress = MAX(0, MIN(1, 1 - self.behaviorRemaining / MMJumpDuration));
    CGFloat jumpHeight = sin(progress * M_PI) * 52;
    [self.panel setFrameOrigin:NSMakePoint(self.panel.frame.origin.x, self.baseY + jumpHeight)];
}

- (void)chooseNextBehavior:(BOOL)forceRest {
    self.targetX = nil;
    if (forceRest) {
        uint32_t restRoll = arc4random_uniform(100);
        if (restRoll < 62) [self enterMode:MMPetModeIdle duration:MMRandom(4.5, 9.0)];
        else if (restRoll < 78) [self enterMode:MMPetModeWave duration:2.4];
        else if (restRoll < 90) [self enterMode:MMPetModePlay duration:3.2];
        else [self enterMode:MMPetModeReview duration:3.6];
        return;
    }
    uint32_t roll = arc4random_uniform(100);
    if (roll < 22) [self beginWalk];
    else if (roll < 72) [self enterMode:MMPetModeIdle duration:MMRandom(5.0, 11.0)];
    else if (roll < 82) [self enterMode:MMPetModeWave duration:2.4];
    else if (roll < 88) [self enterMode:MMPetModeJump duration:MMJumpDuration];
    else if (roll < 96) [self enterMode:MMPetModePlay duration:3.2];
    else [self enterMode:MMPetModeReview duration:3.6];
}

- (void)beginWalk {
    NSScreen *screen = [self currentScreen];
    if (!screen) return;
    self.baseY = NSMinY(screen.visibleFrame) + 6;
    CGFloat minX = NSMinX(screen.visibleFrame);
    CGFloat maxX = NSMaxX(screen.visibleFrame) - self.petSize.width;
    CGFloat currentX = MIN(MAX(self.panel.frame.origin.x, minX), maxX);
    CGFloat leftRoom = currentX - minX;
    CGFloat rightRoom = maxX - currentX;
    BOOL goRight;
    if (rightRoom < 120) goRight = NO;
    else if (leftRoom < 120) goRight = YES;
    else goRight = arc4random_uniform(2) == 0;
    CGFloat available = goRight ? rightRoom : leftRoom;
    if (available < 40) {
        [self enterMode:MMPetModeIdle duration:MMRandom(5.0, 9.0)];
        return;
    }
    CGFloat minimumDistance = MIN(140, available);
    CGFloat maximumDistance = MIN(360, available);
    CGFloat distance = MMRandom(minimumDistance, maximumDistance);
    CGFloat destination = currentX + (goRight ? distance : -distance);
    self.targetX = @(destination);
    MMPetMode walkMode = goRight ? MMPetModeWalkRight : MMPetModeWalkLeft;
    [self enterMode:walkMode duration:distance / MMWalkSpeed + 0.35];
}

- (void)enterMode:(MMPetMode)mode duration:(double)duration {
    self.mode = mode;
    self.animationElapsed = 0;
    self.behaviorRemaining = duration;
    [self applyAnimationFrame];
    if (mode != MMPetModeJump) {
        [self.panel setFrameOrigin:NSMakePoint(self.panel.frame.origin.x, self.baseY)];
    }
}

- (void)applyAnimationFrame {
    MMAnimation animation = MMAnimationForMode(self.mode);
    self.petView.row = animation.row;
    self.petView.column = ((NSInteger)floor(self.animationElapsed * animation.fps)) % animation.frames;
    self.petView.flippedHorizontally = self.mode == MMPetModeWalkLeft;
}

- (void)placeNearMouse {
    NSPoint mouse = NSEvent.mouseLocation;
    NSScreen *screen = [self screenContainingPoint:mouse] ?: NSScreen.mainScreen;
    if (!screen) return;
    self.baseY = NSMinY(screen.visibleFrame) + 6;
    CGFloat x = MIN(MAX(mouse.x - self.petSize.width / 2, NSMinX(screen.visibleFrame)), NSMaxX(screen.visibleFrame) - self.petSize.width);
    [self.panel setFrame:NSMakeRect(x, self.baseY, self.petSize.width, self.petSize.height) display:YES];
    [self updateBubblePosition];
}

- (void)dragTo:(NSPoint)mouse {
    NSScreen *screen = [self screenContainingPoint:mouse] ?: NSScreen.mainScreen;
    if (!screen) return;
    if (!self.dragging) {
        [self noteInteraction];
        [self clearEdgeStateAndReveal];
        [self hideBubble];
    }
    self.dragging = YES;
    self.dropping = NO;
    self.targetX = nil;
    self.baseY = NSMinY(screen.visibleFrame) + 6;
    CGFloat x = MIN(MAX(mouse.x - self.petSize.width / 2, NSMinX(screen.visibleFrame)), NSMaxX(screen.visibleFrame) - self.petSize.width);
    BOOL lifted = mouse.y > self.baseY + self.petSize.height * 0.72;
    CGFloat y = self.baseY;
    if (lifted) {
        y = mouse.y - self.petSize.height + self.petSize.height * 0.22;
        y = MIN(MAX(y, self.baseY), NSMaxY(screen.visibleFrame) - self.petSize.height);
    }
    x = round(x * screen.backingScaleFactor) / screen.backingScaleFactor;
    y = round(y * screen.backingScaleFactor) / screen.backingScaleFactor;
    [self.panel setFrameOrigin:NSMakePoint(x, y)];
    [self updateBubblePosition];
    self.liftedDuringDrag = lifted;
    self.petView.flippedHorizontally = NO;
    if (lifted) {
        self.petView.row = 4;
        self.petView.column = 1 + ((NSInteger)floor(NSProcessInfo.processInfo.systemUptime * 1.6) % 3);
    } else {
        self.petView.row = 0;
        self.petView.column = 0;
    }
}

- (void)dragFinished {
    self.dragging = NO;
    self.paused = NO;
    [self noteInteraction];
    if (self.liftedDuringDrag || self.panel.frame.origin.y > self.baseY + 1) {
        self.dropping = YES;
        self.dropVelocity = 0;
        self.mode = MMPetModeJump;
        self.behaviorRemaining = MMJumpDuration;
        self.petView.row = 4;
        self.petView.column = 3;
        self.petView.flippedHorizontally = NO;
    } else {
        [self settleAfterDrag];
    }
    self.liftedDuringDrag = NO;
    if (self.onPauseChanged) self.onPauseChanged(NO);
}

- (void)updateDrop:(NSTimeInterval)delta {
    self.dropVelocity -= 560.0 * delta;
    CGFloat y = self.panel.frame.origin.y + self.dropVelocity * delta;
    if (y <= self.baseY) {
        [self.panel setFrameOrigin:NSMakePoint(self.panel.frame.origin.x, self.baseY)];
        self.dropping = NO;
        [self settleAfterDrag];
        return;
    }
    self.petView.row = 4;
    self.petView.column = y - self.baseY > self.petSize.height * 0.45 ? 2 : 3;
    self.petView.flippedHorizontally = NO;
    [self.panel setFrameOrigin:NSMakePoint(self.panel.frame.origin.x, y)];
}

- (void)settleAfterDrag {
    NSScreen *screen = [self currentScreen];
    if (!screen) return;
    CGFloat minX = NSMinX(screen.visibleFrame);
    CGFloat maxX = NSMaxX(screen.visibleFrame) - self.petSize.width;
    CGFloat x = MIN(MAX(self.panel.frame.origin.x, minX), maxX);
    CGFloat cornerDistance = MAX(28.0, self.petSize.width * 0.30);
    self.parkedEdge = 0;
    if (x - minX <= cornerDistance) {
        self.parkedEdge = -1;
        x = minX;
    } else if (maxX - x <= cornerDistance) {
        self.parkedEdge = 1;
        x = maxX;
    }
    [self.panel setFrameOrigin:NSMakePoint(x, self.baseY)];
    if (self.parkedEdge != 0) {
        [self enterMode:MMPetModeIdle duration:DBL_MAX];
    } else {
        [self enterMode:MMPetModeWave duration:2.4];
    }
}

- (void)beginEdgeRetreat {
    if (self.parkedEdge == 0 || self.edgeRetreating || self.edgeHidden || self.edgeEmerging) return;
    self.edgeRetreating = YES;
    [self enterMode:self.parkedEdge < 0 ? MMPetModeWalkLeft : MMPetModeWalkRight duration:DBL_MAX];
}

- (void)updateEdgeRetreat:(NSTimeInterval)delta {
    NSScreen *screen = [self currentScreen];
    if (!screen) return;
    CGFloat target = self.parkedEdge < 0
        ? NSMinX(screen.visibleFrame) - self.petSize.width + MMEdgePeekWidth
        : NSMaxX(screen.visibleFrame) - MMEdgePeekWidth;
    CGFloat direction = self.parkedEdge < 0 ? -1 : 1;
    CGFloat x = self.panel.frame.origin.x + direction * MMEdgeHideSpeed * delta;
    BOOL arrived = (direction < 0 && x <= target) || (direction > 0 && x >= target);
    if (arrived) x = target;
    x = round(x * screen.backingScaleFactor) / screen.backingScaleFactor;
    [self.panel setFrameOrigin:NSMakePoint(x, self.baseY)];
    if (arrived) {
        self.edgeRetreating = NO;
        self.edgeHidden = YES;
        [self enterMode:MMPetModeIdle duration:DBL_MAX];
        [self.panel setFrameOrigin:NSMakePoint(x, self.baseY)];
    }
}

- (void)updateEdgeEmergence:(NSTimeInterval)delta {
    NSScreen *screen = [self currentScreen];
    if (!screen || self.parkedEdge == 0) {
        self.edgeEmerging = NO;
        return;
    }
    self.edgeEmergenceElapsed += delta;
    double progress = MIN(1.0, self.edgeEmergenceElapsed / MMEdgeEmergenceDuration);
    double eased = 1.0 - pow(1.0 - progress, 3.0);
    CGFloat targetX = self.parkedEdge < 0
        ? NSMinX(screen.visibleFrame)
        : NSMaxX(screen.visibleFrame) - self.petSize.width;
    CGFloat x = self.edgeEmergenceStartX + (targetX - self.edgeEmergenceStartX) * eased;
    CGFloat y = self.baseY + sin(progress * M_PI) * MMEdgeEmergenceHopHeight;
    x = round(x * screen.backingScaleFactor) / screen.backingScaleFactor;
    y = round(y * screen.backingScaleFactor) / screen.backingScaleFactor;
    self.petView.row = 4;
    self.petView.column = MIN(4, (NSInteger)floor(progress * 5.0));
    self.petView.flippedHorizontally = NO;
    [self.panel setFrameOrigin:NSMakePoint(x, y)];

    if (progress >= 1.0) {
        self.edgeEmerging = NO;
        [self.panel setFrameOrigin:NSMakePoint(targetX, self.baseY)];
        [self noteInteraction];
        [self enterMode:MMPetModeIdle duration:DBL_MAX];
    }
}

- (void)clearEdgeStateAndReveal {
    if (self.parkedEdge == 0 && !self.edgeRetreating && !self.edgeHidden && !self.edgeEmerging) return;
    NSScreen *screen = [self currentScreen];
    if (screen && (self.edgeRetreating || self.edgeHidden || self.edgeEmerging)) {
        CGFloat x = self.parkedEdge < 0
            ? NSMinX(screen.visibleFrame)
            : NSMaxX(screen.visibleFrame) - self.petSize.width;
        [self.panel setFrameOrigin:NSMakePoint(x, NSMinY(screen.visibleFrame) + 6)];
        self.baseY = NSMinY(screen.visibleFrame) + 6;
    }
    self.parkedEdge = 0;
    self.edgeRetreating = NO;
    self.edgeHidden = NO;
    self.edgeEmerging = NO;
}

- (void)noteInteraction {
    self.lastInteractionAt = NSProcessInfo.processInfo.systemUptime;
}

- (NSScreen *)screenContainingPoint:(NSPoint)point {
    for (NSScreen *screen in NSScreen.screens) {
        if (NSPointInRect(point, screen.frame)) return screen;
    }
    return nil;
}

- (NSScreen *)currentScreen {
    NSPoint center = NSMakePoint(NSMidX(self.panel.frame), NSMidY(self.panel.frame));
    return [self screenContainingPoint:center] ?: NSScreen.mainScreen;
}

- (void)scheduleNextJokeFrom:(NSTimeInterval)now {
    self.nextJokeAt = now + MMRandom(40.0 * 60.0, 90.0 * 60.0);
}

- (void)showRandomJoke {
    NSArray<NSString *> *jokes = MMColdJokes();
    self.bubbleView.message = jokes[arc4random_uniform((uint32_t)jokes.count)];
    [self updateBubblePosition];
    [self.bubblePanel orderFrontRegardless];
    NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    self.bubbleHideAt = now + MMJokeDisplayDuration;
    [self scheduleNextJokeFrom:now];
}

- (void)hideBubble {
    [self.bubblePanel orderOut:nil];
    self.bubbleHideAt = 0;
}

- (void)updateBubblePosition {
    if (!self.bubblePanel.visible && self.bubbleView.message.length == 0) return;
    NSScreen *screen = [self currentScreen];
    if (!screen) return;
    NSRect visible = screen.visibleFrame;
    CGFloat x = NSMidX(self.panel.frame) - MMBubbleWidth / 2.0;
    x = MIN(MAX(x, NSMinX(visible) + 6), NSMaxX(visible) - MMBubbleWidth - 6);
    CGFloat y = NSMaxY(self.panel.frame) + 4;
    if (y + MMBubbleHeight > NSMaxY(visible) - 6) {
        y = NSMinY(self.panel.frame) - MMBubbleHeight - 4;
    }
    y = MIN(MAX(y, NSMinY(visible) + 6), NSMaxY(visible) - MMBubbleHeight - 6);
    [self.bubblePanel setFrame:NSMakeRect(x, y, MMBubbleWidth, MMBubbleHeight) display:YES];
}

@end

@interface MMAppDelegate : NSObject <NSApplicationDelegate>
@property(nonatomic, strong) MMPetController *controller;
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) NSMenuItem *pauseItem;
@property(nonatomic, strong) NSMenuItem *visibilityItem;
@end

@implementation MMAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    NSURL *atlasURL = [NSBundle.mainBundle URLForResource:@"spritesheet" withExtension:@"webp"];
    NSImage *atlas = atlasURL ? [[NSImage alloc] initWithContentsOfURL:atlasURL] : nil;
    if (!atlas) {
        NSAlert *alert = [NSAlert new];
        alert.messageText = @"妹妹没有找到她的动画图集";
        alert.informativeText = @"请确认 spritesheet.webp 位于应用 Resources 目录。";
        [alert runModal];
        [NSApp terminate:nil];
        return;
    }

    self.controller = [[MMPetController alloc] initWithAtlas:atlas];
    [self configureStatusItem];
}

- (void)configureStatusItem {
    self.statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSSquareStatusItemLength];
    self.statusItem.button.image = [NSImage imageWithSystemSymbolName:@"pawprint.fill" accessibilityDescription:@"妹妹"];
    self.statusItem.button.toolTip = @"妹妹";

    NSMenu *menu = [NSMenu new];
    NSMenuItem *title = [[NSMenuItem alloc] initWithTitle:@"妹妹 · 陨石边牧" action:nil keyEquivalent:@""];
    title.enabled = NO;
    [menu addItem:title];
    [menu addItem:NSMenuItem.separatorItem];
    [menu addItem:[self item:@"叫妹妹过来" action:@selector(bringPet:) key:@"b"]];
    [menu addItem:[self item:@"和妹妹玩" action:@selector(playWithPet:) key:@"p"]];
    [menu addItem:[self item:@"妹妹，讲个冷笑话" action:@selector(tellJoke:) key:@"j"]];

    self.pauseItem = [self item:@"暂停散步" action:@selector(togglePause:) key:@" "];
    [menu addItem:self.pauseItem];
    self.visibilityItem = [self item:@"隐藏妹妹" action:@selector(toggleVisibility:) key:@"h"];
    [menu addItem:self.visibilityItem];
    [menu addItem:NSMenuItem.separatorItem];
    [menu addItem:[self item:@"退出妹妹" action:@selector(quit:) key:@"q"]];
    self.statusItem.menu = menu;

    __weak typeof(self) weakSelf = self;
    self.controller.onPauseChanged = ^(BOOL paused) {
        weakSelf.pauseItem.title = paused ? @"继续散步" : @"暂停散步";
    };
    self.controller.onVisibilityChanged = ^(BOOL hidden) {
        weakSelf.visibilityItem.title = hidden ? @"显示妹妹" : @"隐藏妹妹";
    };
}

- (NSMenuItem *)item:(NSString *)title action:(SEL)action key:(NSString *)key {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:key];
    item.target = self;
    return item;
}

- (void)bringPet:(id)sender { [self.controller bringToMouse]; }
- (void)playWithPet:(id)sender { [self.controller playNow]; }
- (void)tellJoke:(id)sender { [self.controller tellJokeNow]; }
- (void)togglePause:(id)sender { [self.controller togglePause]; }
- (void)toggleVisibility:(id)sender { [self.controller toggleVisibility]; }
- (void)quit:(id)sender { [NSApp terminate:nil]; }

@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if ([NSProcessInfo.processInfo.arguments containsObject:@"--print-pet-size"]) {
            CGFloat width = MMCurrentCodexPetWidth();
            printf("%.0fx%.2f\n", width, width * 208.0 / 192.0);
            return 0;
        }
        if ([NSProcessInfo.processInfo.arguments containsObject:@"--print-behavior-config"]) {
            printf("walk_fps=5.2 walk_speed=42 idle_fps=2.0 play_fps=2.1 corner_hide_seconds=300 hover_reveal=jump-to-corner left_source=running-right-mirrored\n");
            return 0;
        }
        NSApplication *app = NSApplication.sharedApplication;
        MMAppDelegate *delegate = [MMAppDelegate new];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
