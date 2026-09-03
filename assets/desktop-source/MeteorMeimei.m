#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>
#import <math.h>

typedef NS_ENUM(NSInteger, MMPetMode) {
    MMPetModeIdle,
    MMPetModeWalkRight,
    MMPetModeWalkLeft,
    MMPetModeWave,
    MMPetModeJump,
    MMPetModePlay,
    MMPetModeReview,
    MMPetModeCute,
    MMPetModeEat,
    MMPetModeBelly,
    MMPetModeRoll,
    MMPetModeApproach,
    MMPetModeStartup,
    MMPetModeExpectant
};

typedef struct {
    NSInteger row;
    NSInteger frames;
    double fps;
} MMAnimation;

static MMAnimation MMAnimationForMode(MMPetMode mode) {
    switch (mode) {
        case MMPetModeIdle:      return (MMAnimation){14, 8, 1.4};
        case MMPetModeWalkRight: return (MMAnimation){17, 8, 5.0};
        case MMPetModeWalkLeft:  return (MMAnimation){16, 8, 5.0};
        case MMPetModeWave:      return (MMAnimation){11, 8, 1.6};
        case MMPetModeJump:      return (MMAnimation){12, 8, 1.6};
        case MMPetModePlay:      return (MMAnimation){18, 8, 1.5};
        case MMPetModeReview:    return (MMAnimation){14, 8, 1.4};
        case MMPetModeCute:      return (MMAnimation){11, 8, 1.6};
        case MMPetModeEat:       return (MMAnimation){12, 8, 1.6};
        case MMPetModeBelly:     return (MMAnimation){13, 8, 1.6};
        case MMPetModeRoll:      return (MMAnimation){13, 8, 1.6};
        case MMPetModeApproach:  return (MMAnimation){18, 8, 1.5};
        case MMPetModeStartup:   return (MMAnimation){15, 8, 4.0};
        case MMPetModeExpectant: return (MMAnimation){18, 8, 1.5};
    }
}

static BOOL MMAnimationLoops(MMPetMode mode) {
    switch (mode) {
        case MMPetModeIdle:
        case MMPetModeWalkRight:
        case MMPetModeWalkLeft:
        case MMPetModeReview:
            return YES;
        default:
            return NO;
    }
}

static const NSTimeInterval MMActionEntryHoldDuration = 0.18;
static const NSTimeInterval MMActionExitHoldDuration = 0.32;

static double MMActionDuration(MMPetMode mode) {
    MMAnimation animation = MMAnimationForMode(mode);
    if (MMAnimationLoops(mode)) return (double)animation.frames / animation.fps;
    return MMActionEntryHoldDuration
        + (double)(animation.frames - 1) / animation.fps
        + MMActionExitHoldDuration;
}

static CGFloat MMRandom(CGFloat minimum, CGFloat maximum) {
    CGFloat unit = (CGFloat)arc4random() / (CGFloat)UINT32_MAX;
    return minimum + (maximum - minimum) * unit;
}

static CGFloat MMDesktopPetWidth(void) {
    return 97.0;
}

static CGFloat MMDisplayScaleForMode(MMPetMode mode) {
    switch (mode) {
        case MMPetModeWalkRight:
        case MMPetModeWalkLeft:
            return 1.5;
        case MMPetModeBelly:
        case MMPetModeRoll:
            return 1.8;
        default:
            return 1.0;
    }
}

static const NSTimeInterval MMActionTransitionDuration = 0.62;
static const CGFloat MMPettingDistanceThreshold = 84.0;
static const NSTimeInterval MMPettingResetInterval = 1.25;
static const NSTimeInterval MMPettingCooldown = 12.0;

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

static NSArray<NSString *> *MMWellnessMessages(void) {
    static NSArray<NSString *> *messages;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        messages = @[
            @"工作一小时啦～陪妹妹起来活动 2–5 分钟，再喝几口水吧 🐾",
            @"妹妹来报时：站起来伸伸腰、走一走，也别忘了喝水呀。",
            @"先暂停一下下～活动肩颈 2–5 分钟，再补几口水吧。",
            @"汪～妹妹提醒你休息一下：起来动一动，顺便喝点水。"
        ];
    });
    return messages;
}

@interface MMPetView : NSView
@property(nonatomic, strong) NSImage *atlas;
@property(nonatomic, strong) NSImage *actionAtlas;
@property(nonatomic) NSInteger row;
@property(nonatomic) NSInteger column;
@property(nonatomic) BOOL flippedHorizontally;
@property(nonatomic) NSInteger previousRow;
@property(nonatomic) NSInteger previousColumn;
@property(nonatomic) BOOL previousFlippedHorizontally;
@property(nonatomic) NSTimeInterval transitionStartedAt;
@property(nonatomic, copy) void (^onClick)(void);
@property(nonatomic, copy) void (^onDoubleClick)(void);
@property(nonatomic, copy) void (^onPet)(void);
@property(nonatomic, copy) void (^onDrag)(NSPoint point);
@property(nonatomic, copy) void (^onDragEnd)(void);
@property(nonatomic, copy) void (^onHover)(void);
@property(nonatomic, copy) void (^onTemporaryQuit)(void);
@property(nonatomic, strong) NSTrackingArea *hoverTrackingArea;
@property(nonatomic) BOOL didDrag;
@property(nonatomic) NSUInteger pendingClickToken;
@property(nonatomic) NSPoint lastPetPoint;
@property(nonatomic) CGFloat pettingDistance;
@property(nonatomic) NSTimeInterval lastPetMovementAt;
@property(nonatomic) NSTimeInterval pettingCooldownUntil;
@property(nonatomic) BOOL hasLastPetPoint;
@end

@implementation MMPetView

- (instancetype)initWithFrame:(NSRect)frame atlas:(NSImage *)atlas actionAtlas:(NSImage *)actionAtlas {
    self = [super initWithFrame:frame];
    if (self) {
        _atlas = atlas;
        _actionAtlas = actionAtlas;
        _row = -1;
        _previousRow = -1;
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
             options:NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved | NSTrackingActiveAlways | NSTrackingInVisibleRect
               owner:self
            userInfo:nil];
    [self addTrackingArea:self.hoverTrackingArea];
}

- (void)mouseEntered:(NSEvent *)event {
    self.hasLastPetPoint = NO;
    self.pettingDistance = 0;
    if (self.onHover) self.onHover();
}

- (void)mouseExited:(NSEvent *)event {
    self.hasLastPetPoint = NO;
    self.pettingDistance = 0;
}

- (void)mouseMoved:(NSEvent *)event {
    if (self.didDrag) return;
    NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    if (now < self.pettingCooldownUntil) {
        self.lastPetPoint = point;
        self.lastPetMovementAt = now;
        self.hasLastPetPoint = YES;
        return;
    }
    if (!self.hasLastPetPoint || now - self.lastPetMovementAt > MMPettingResetInterval) {
        self.pettingDistance = 0;
        self.lastPetPoint = point;
        self.lastPetMovementAt = now;
        self.hasLastPetPoint = YES;
        return;
    }

    CGFloat distance = hypot(point.x - self.lastPetPoint.x, point.y - self.lastPetPoint.y);
    if (distance >= 2.0 && distance <= 40.0) self.pettingDistance += distance;
    self.lastPetPoint = point;
    self.lastPetMovementAt = now;
    if (self.pettingDistance >= MMPettingDistanceThreshold) {
        self.pettingDistance = 0;
        self.pettingCooldownUntil = now + MMPettingCooldown;
        if (self.onPet) self.onPet();
    }
}

- (void)setRow:(NSInteger)row {
    if (_row == row) return;
    if (_row >= 0) {
        _previousRow = _row;
        _previousColumn = _column;
        _previousFlippedHorizontally = _flippedHorizontally;
        _transitionStartedAt = NSProcessInfo.processInfo.systemUptime;
    }
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

- (void)drawFrameAtRow:(NSInteger)row
                column:(NSInteger)column
               flipped:(BOOL)flipped
              fraction:(CGFloat)fraction {
    if (row < 0 || fraction <= 0) return;
    BOOL usesActionAtlas = row >= 11;
    NSImage *sourceAtlas = usesActionAtlas ? self.actionAtlas : self.atlas;
    NSInteger sourceRow = usesActionAtlas ? row - 11 : row;
    if (sourceAtlas.size.width < 1536 || sourceAtlas.size.height < (sourceRow + 1) * 208) return;
    CGFloat cellWidth = 192;
    CGFloat cellHeight = 208;
    CGFloat sourceY = sourceAtlas.size.height - ((CGFloat)sourceRow + 1) * cellHeight;
    NSRect source = NSMakeRect((CGFloat)column * cellWidth, sourceY, cellWidth, cellHeight);
    [NSGraphicsContext saveGraphicsState];
    if (flipped) {
        NSAffineTransform *flip = [NSAffineTransform transform];
        [flip translateXBy:NSWidth(self.bounds) yBy:0];
        [flip scaleXBy:-1 yBy:1];
        [flip concat];
    }
    [sourceAtlas drawInRect:self.bounds
                   fromRect:source
                  operation:NSCompositingOperationSourceOver
                   fraction:fraction
             respectFlipped:NO
                      hints:nil];
    [NSGraphicsContext restoreGraphicsState];
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    [[NSColor clearColor] setFill];
    NSRectFillUsingOperation(self.bounds, NSCompositingOperationCopy);
    NSGraphicsContext.currentContext.imageInterpolation = NSImageInterpolationHigh;

    CGFloat progress = 1.0;
    if (self.previousRow >= 0) {
        NSTimeInterval elapsed = NSProcessInfo.processInfo.systemUptime - self.transitionStartedAt;
        progress = MIN(1.0, MAX(0.0, elapsed / MMActionTransitionDuration));
        progress = progress * progress * (3.0 - 2.0 * progress);
    }
    if (progress < 1.0) {
        [self drawFrameAtRow:self.previousRow
                     column:self.previousColumn
                    flipped:self.previousFlippedHorizontally
                   fraction:1.0 - progress];
        [self drawFrameAtRow:self.row column:0 flipped:self.flippedHorizontally fraction:progress];
        self.needsDisplay = YES;
    } else {
        self.previousRow = -1;
        [self drawFrameAtRow:self.row
                     column:self.column
                    flipped:self.flippedHorizontally
                   fraction:1.0];
    }
}

- (void)mouseDown:(NSEvent *)event {
    self.didDrag = NO;
}

- (void)mouseDragged:(NSEvent *)event {
    self.didDrag = YES;
    self.pendingClickToken += 1;
    if (self.onDrag) self.onDrag(NSEvent.mouseLocation);
}

- (void)mouseUp:(NSEvent *)event {
    if (self.didDrag) {
        if (self.onDragEnd) self.onDragEnd();
    } else if (event.clickCount >= 2) {
        self.pendingClickToken += 1;
        if (self.onDoubleClick) self.onDoubleClick();
    } else {
        NSUInteger token = ++self.pendingClickToken;
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(NSEvent.doubleClickInterval * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf && strongSelf.pendingClickToken == token && strongSelf.onClick) {
                strongSelf.onClick();
            }
        });
    }
    self.didDrag = NO;
}

- (void)rightMouseDown:(NSEvent *)event {
    NSMenu *menu = [NSMenu new];
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"暂时退出妹妹"
                                                     action:@selector(temporarilyQuit:)
                                              keyEquivalent:@""];
    quitItem.target = self;
    [menu addItem:quitItem];
    [NSMenu popUpContextMenu:menu withEvent:event forView:self];
}

- (void)temporarilyQuit:(id)sender {
    if (self.onTemporaryQuit) self.onTemporaryQuit();
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
@property(nonatomic) NSTimeInterval nextWellnessAt;
@property(nonatomic) NSTimeInterval nextRollAt;
@property(nonatomic) NSTimeInterval bubbleHideAt;
@property(nonatomic) MMPetMode mode;
@property(nonatomic) double animationElapsed;
@property(nonatomic) double behaviorRemaining;
@property(nonatomic, strong) NSNumber *targetX;
@property(nonatomic) CGFloat baseY;
@property(nonatomic) NSSize petSize;
@property(nonatomic) CGFloat currentDisplayScale;
@property(nonatomic) CGFloat displayScaleFrom;
@property(nonatomic) CGFloat displayScaleTo;
@property(nonatomic) NSTimeInterval displayScaleStartedAt;
@property(nonatomic) CGFloat dropVelocity;
@property(nonatomic) CGFloat edgeEmergenceStartX;
@property(nonatomic) NSInteger parkedEdge;
@property(nonatomic) NSTimeInterval lastInteractionAt;
@property(nonatomic) NSTimeInterval edgeEmergenceElapsed;
@property(nonatomic) NSTimeInterval nextFocusProtectionCheckAt;
@property(nonatomic) NSInteger wellnessReturnEdge;
@property(nonatomic) BOOL paused;
@property(nonatomic) BOOL petHidden;
@property(nonatomic) BOOL focusProtected;
@property(nonatomic) BOOL cinemaMode;
@property(nonatomic) BOOL dragging;
@property(nonatomic) BOOL liftedDuringDrag;
@property(nonatomic) BOOL dropping;
@property(nonatomic) BOOL edgeRetreating;
@property(nonatomic) BOOL edgeHidden;
@property(nonatomic) BOOL edgeEmerging;
@property(nonatomic) BOOL wellnessReminderActive;
@property(nonatomic, copy) void (^onPauseChanged)(BOOL paused);
@property(nonatomic, copy) void (^onVisibilityChanged)(BOOL hidden);
@property(nonatomic, copy) void (^onCinemaModeChanged)(BOOL enabled);
- (instancetype)initWithAtlas:(NSImage *)atlas actionAtlas:(NSImage *)actionAtlas;
- (void)togglePause;
- (void)toggleVisibility;
- (void)playNow;
- (void)playMode:(MMPetMode)mode;
- (void)bringToMouse;
- (void)tellJokeNow;
- (void)petNow;
- (void)hoverReveal;
- (void)toggleCinemaMode;
- (void)dragFinished;
- (void)scheduleNextRollFrom:(NSTimeInterval)now;
- (void)maybePlayScheduledRoll:(NSTimeInterval)now;
- (void)updateDisplayScale:(NSTimeInterval)now;
- (void)setDisplayScaleImmediately:(CGFloat)scale;
@end

@implementation MMPetController

static const CGFloat MMBubbleWidth = 236;
static const CGFloat MMBubbleHeight = 78;
static const NSTimeInterval MMJokeDisplayDuration = 8.0;
static const NSTimeInterval MMWellnessInterval = 60.0 * 60.0;
static const NSTimeInterval MMRollIntervalMinimum = 8.0 * 60.0;
static const NSTimeInterval MMRollIntervalMaximum = 18.0 * 60.0;
static const NSTimeInterval MMWellnessDisplayDuration = 10.0;
static const NSTimeInterval MMWorkActivityWindow = 5.0 * 60.0;
static const NSTimeInterval MMCornerHideDelay = 5.0 * 60.0;
static const CGFloat MMWalkSpeed = 42.0;
static const CGFloat MMEdgeHideSpeed = 30.0;
static const CGFloat MMEdgePeekWidth = 24.0;
static const CGFloat MMEdgeEmergenceHopHeight = 28.0;
static const NSTimeInterval MMEdgeEmergenceDuration = 0.82;
static const NSTimeInterval MMFocusProtectionInterval = 0.4;
static const NSTimeInterval MMTypingQuietPeriod = 3.0;
static const double MMJumpDuration = 1.8;

- (instancetype)initWithAtlas:(NSImage *)atlas actionAtlas:(NSImage *)actionAtlas {
    self = [super init];
    if (self) {
        CGFloat petWidth = MMDesktopPetWidth();
        _petSize = NSMakeSize(petWidth, petWidth * 208.0 / 192.0);
        _currentDisplayScale = 1.0;
        _displayScaleFrom = 1.0;
        _displayScaleTo = 1.0;
        _displayScaleStartedAt = NSProcessInfo.processInfo.systemUptime;
        NSRect frame = NSMakeRect(0, 0, _petSize.width, _petSize.height);
        _panel = [[MMPetPanel alloc] initWithContentRect:frame
                                              styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
        _petView = [[MMPetView alloc] initWithFrame:frame atlas:atlas actionAtlas:actionAtlas];
        _panel.contentView = _petView;
        _panel.opaque = NO;
        _panel.backgroundColor = NSColor.clearColor;
        _panel.hasShadow = NO;
        _panel.level = NSFloatingWindowLevel;
        _panel.ignoresMouseEvents = NO;
        _panel.acceptsMouseMovedEvents = YES;
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
        _petView.onDoubleClick = ^{ [weakSelf tellJokeNow]; };
        _petView.onPet = ^{ [weakSelf petNow]; };
        _petView.onDrag = ^(NSPoint point) { [weakSelf dragTo:point]; };
        _petView.onDragEnd = ^{ [weakSelf dragFinished]; };
        _petView.onHover = ^{ [weakSelf hoverReveal]; };
        _petView.onTemporaryQuit = ^{ [NSApp terminate:nil]; };

        [self placeNearMouse];
        [_panel orderFrontRegardless];
        [self enterMode:MMPetModeStartup duration:MMActionDuration(MMPetModeStartup)];
        _lastTick = NSProcessInfo.processInfo.systemUptime;
        _lastInteractionAt = _lastTick;
        [self scheduleNextJokeFrom:_lastTick];
        [self scheduleNextWellnessFrom:_lastTick];
        [self scheduleNextRollFrom:_lastTick];
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
        if (!self.focusProtected) [self.panel orderFrontRegardless];
        [self enterMode:MMPetModeWave duration:2.4];
    }
    if (self.onVisibilityChanged) self.onVisibilityChanged(self.petHidden);
}

- (void)playNow {
    MMPetMode choices[] = { MMPetModeCute, MMPetModeEat, MMPetModeRoll, MMPetModeExpectant };
    [self playMode:choices[arc4random_uniform(4)]];
}

- (void)playMode:(MMPetMode)mode {
    if (self.petHidden) return;
    [self noteInteraction];
    [self clearEdgeStateAndReveal];
    self.paused = NO;
    if (self.onPauseChanged) self.onPauseChanged(NO);
    [self enterMode:mode duration:MMActionDuration(mode)];
    if (mode == MMPetModeBelly || mode == MMPetModeRoll) {
        [self scheduleNextRollFrom:NSProcessInfo.processInfo.systemUptime];
    }
}

- (void)bringToMouse {
    self.petHidden = NO;
    [self noteInteraction];
    [self clearEdgeStateAndReveal];
    if (self.onVisibilityChanged) self.onVisibilityChanged(NO);
    [self placeNearMouse];
    if (!self.focusProtected) [self.panel orderFrontRegardless];
    [self enterMode:MMPetModeApproach duration:MMActionDuration(MMPetModeApproach)];
}

- (void)tellJokeNow {
    if (self.petHidden || self.edgeHidden || self.edgeRetreating || self.edgeEmerging) [self bringToMouse];
    [self noteInteraction];
    if (!self.focusProtected) [self showRandomJoke];
}

- (void)petNow {
    if (self.petHidden || self.focusProtected || self.dragging || self.edgeEmerging) return;
    [self playMode:MMPetModeEat];
}

- (void)toggleCinemaMode {
    self.cinemaMode = !self.cinemaMode;
    self.nextFocusProtectionCheckAt = 0;
    [self updateFocusProtection:NSProcessInfo.processInfo.systemUptime];
    if (self.onCinemaModeChanged) self.onCinemaModeChanged(self.cinemaMode);
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
    self.petView.row = 12;
    self.petView.column = 0;
    self.petView.flippedHorizontally = NO;
    if (self.onPauseChanged) self.onPauseChanged(NO);
}

- (void)tick:(NSTimer *)timer {
    NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    NSTimeInterval delta = MIN(now - self.lastTick, 0.1);
    self.lastTick = now;
    [self updateDisplayScale:now];
    [self updateFocusProtection:now];
    if (self.bubblePanel.visible && now >= self.bubbleHideAt) [self hideBubble];
    [self maybeShowWellnessReminder:now];
    if (self.paused || self.petHidden || self.focusProtected) return;
    if (!self.bubblePanel.visible && now >= self.nextJokeAt) [self showRandomJoke];
    [self maybePlayScheduledRoll:now];
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
    if (self.animationElapsed < 0) return;
    NSScreen *screen = [self currentScreen];
    if (!screen || !self.targetX) {
        [self chooseNextBehavior:NO];
        return;
    }
    CGFloat direction = self.mode == MMPetModeWalkRight ? 1 : -1;
    CGFloat x = self.panel.frame.origin.x + direction * MMWalkSpeed * delta;
    CGFloat minX = NSMinX(screen.visibleFrame);
    CGFloat maxX = NSMaxX(screen.visibleFrame) - NSWidth(self.panel.frame);
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
        if (restRoll < 88) [self enterMode:MMPetModeIdle duration:MMRandom(8.0, 16.0)];
        else if (restRoll < 93) [self enterMode:MMPetModeCute duration:MMActionDuration(MMPetModeCute)];
        else if (restRoll < 97) [self enterMode:MMPetModeEat duration:MMActionDuration(MMPetModeEat)];
        else if (restRoll < 99) [self enterMode:MMPetModeWave duration:MMActionDuration(MMPetModeWave)];
        else [self enterMode:MMPetModeReview duration:MMRandom(8.0, 14.0)];
        return;
    }
    uint32_t roll = arc4random_uniform(100);
    if (roll < 12) [self beginWalk];
    else if (roll < 89) [self enterMode:MMPetModeIdle duration:MMRandom(10.0, 22.0)];
    else if (roll < 93) [self enterMode:MMPetModeCute duration:MMActionDuration(MMPetModeCute)];
    else if (roll < 96) [self enterMode:MMPetModeEat duration:MMActionDuration(MMPetModeEat)];
    else if (roll < 98) [self enterMode:MMPetModeWave duration:MMActionDuration(MMPetModeWave)];
    else if (roll < 99) [self enterMode:MMPetModeJump duration:MMJumpDuration];
    else [self enterMode:MMPetModeReview duration:MMRandom(8.0, 14.0)];
}

- (void)beginWalk {
    NSScreen *screen = [self currentScreen];
    if (!screen) return;
    self.baseY = NSMinY(screen.visibleFrame) + 6;
    CGFloat minX = NSMinX(screen.visibleFrame);
    CGFloat walkWidth = self.petSize.width * MMDisplayScaleForMode(MMPetModeWalkRight);
    CGFloat maxX = NSMaxX(screen.visibleFrame) - walkWidth;
    CGFloat currentX = NSMidX(self.panel.frame) - walkWidth / 2.0;
    currentX = MIN(MAX(currentX, minX), maxX);
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
    self.displayScaleFrom = self.currentDisplayScale;
    self.displayScaleTo = MMDisplayScaleForMode(mode);
    self.displayScaleStartedAt = NSProcessInfo.processInfo.systemUptime;
    self.animationElapsed = -MMActionTransitionDuration;
    self.behaviorRemaining = duration + MMActionTransitionDuration;
    [self applyAnimationFrame];
    if (mode != MMPetModeJump) {
        [self.panel setFrameOrigin:NSMakePoint(self.panel.frame.origin.x, self.baseY)];
    }
}

- (void)updateDisplayScale:(NSTimeInterval)now {
    CGFloat target = self.displayScaleTo;
    CGFloat start = self.displayScaleFrom;
    double progress = MIN(1.0, MAX(0.0, (now - self.displayScaleStartedAt) / MMActionTransitionDuration));
    progress = progress * progress * (3.0 - 2.0 * progress);
    CGFloat scale = start + (target - start) * progress;
    if (fabs(scale - self.currentDisplayScale) < 0.0001) return;

    NSRect oldFrame = self.panel.frame;
    NSSize newSize = NSMakeSize(self.petSize.width * scale, self.petSize.height * scale);
    CGFloat x;
    if (self.edgeHidden && self.parkedEdge < 0) {
        x = NSMaxX(oldFrame) - newSize.width;
    } else if (self.edgeHidden && self.parkedEdge > 0) {
        x = NSMinX(oldFrame);
    } else {
        x = NSMidX(oldFrame) - newSize.width / 2.0;
    }
    NSRect newFrame = NSMakeRect(x, NSMinY(oldFrame), newSize.width, newSize.height);
    [self.panel setFrame:newFrame display:YES];
    self.petView.frame = NSMakeRect(0, 0, newSize.width, newSize.height);
    self.currentDisplayScale = scale;
}

- (void)setDisplayScaleImmediately:(CGFloat)scale {
    NSRect oldFrame = self.panel.frame;
    NSSize newSize = NSMakeSize(self.petSize.width * scale, self.petSize.height * scale);
    CGFloat x = NSMidX(oldFrame) - newSize.width / 2.0;
    [self.panel setFrame:NSMakeRect(x, NSMinY(oldFrame), newSize.width, newSize.height) display:YES];
    self.petView.frame = NSMakeRect(0, 0, newSize.width, newSize.height);
    self.currentDisplayScale = scale;
    self.displayScaleFrom = scale;
    self.displayScaleTo = scale;
    self.displayScaleStartedAt = NSProcessInfo.processInfo.systemUptime;
}

- (void)applyAnimationFrame {
    MMAnimation animation = MMAnimationForMode(self.mode);
    self.petView.row = animation.row;
    double activeElapsed = MAX(0.0, self.animationElapsed);
    NSInteger column;
    if (MMAnimationLoops(self.mode)) {
        column = ((NSInteger)floor(activeElapsed * animation.fps)) % animation.frames;
    } else {
        double frameElapsed = MAX(0.0, activeElapsed - MMActionEntryHoldDuration);
        column = MIN(animation.frames - 1, (NSInteger)floor(frameElapsed * animation.fps));
    }
    self.petView.column = column;
    self.petView.flippedHorizontally = NO;
}

- (void)placeNearMouse {
    NSPoint mouse = NSEvent.mouseLocation;
    NSScreen *screen = [self screenContainingPoint:mouse] ?: NSScreen.mainScreen;
    if (!screen) return;
    self.baseY = NSMinY(screen.visibleFrame) + 6;
    CGFloat x = MIN(MAX(mouse.x - self.petSize.width / 2, NSMinX(screen.visibleFrame)), NSMaxX(screen.visibleFrame) - self.petSize.width);
    [self.panel setFrame:NSMakeRect(x, self.baseY, self.petSize.width, self.petSize.height) display:YES];
    self.petView.frame = NSMakeRect(0, 0, self.petSize.width, self.petSize.height);
    self.currentDisplayScale = 1.0;
    self.displayScaleFrom = 1.0;
    self.displayScaleTo = 1.0;
    [self updateBubblePosition];
}

- (void)dragTo:(NSPoint)mouse {
    NSScreen *screen = [self screenContainingPoint:mouse] ?: NSScreen.mainScreen;
    if (!screen) return;
    if (!self.dragging) {
        [self noteInteraction];
        [self clearEdgeStateAndReveal];
        [self hideBubble];
        [self setDisplayScaleImmediately:1.0];
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
        self.petView.row = 18;
        self.petView.column = ((NSInteger)floor(NSProcessInfo.processInfo.systemUptime * 1.5) % 8);
    } else {
        self.petView.row = 14;
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
        self.mode = MMPetModeApproach;
        self.behaviorRemaining = MMJumpDuration;
        self.petView.row = 18;
        self.petView.column = 6;
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
    self.petView.row = 18;
    self.petView.column = y - self.baseY > self.petSize.height * 0.45 ? 5 : 6;
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
    self.petView.row = 12;
    self.petView.column = MIN(7, (NSInteger)floor(progress * 8.0));
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

- (void)updateFocusProtection:(NSTimeInterval)now {
    if (now < self.nextFocusProtectionCheckAt) return;
    self.nextFocusProtectionCheckAt = now + MMFocusProtectionInterval;

    NSTimeInterval secondsSinceKey = CGEventSourceSecondsSinceLastEventType(
        kCGEventSourceStateCombinedSessionState,
        kCGEventKeyDown
    );
    BOOL typing = isfinite(secondsSinceKey) && secondsSinceKey >= 0 && secondsSinceKey < MMTypingQuietPeriod;
    BOOL shouldProtect = self.cinemaMode || typing || [self frontmostAppNeedsQuietScreen];
    if (shouldProtect == self.focusProtected) return;

    self.focusProtected = shouldProtect;
    if (shouldProtect) {
        [self.panel orderOut:nil];
        [self hideBubble];
    } else if (!self.petHidden) {
        [self.panel orderFrontRegardless];
    }
}

- (BOOL)frontmostAppNeedsQuietScreen {
    NSRunningApplication *frontmost = NSWorkspace.sharedWorkspace.frontmostApplication;
    if (!frontmost || frontmost.processIdentifier == NSProcessInfo.processInfo.processIdentifier) return NO;

    static NSSet<NSString *> *mediaBundleIDs;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mediaBundleIDs = [NSSet setWithArray:@[
            @"com.apple.TV",
            @"com.apple.QuickTimePlayerX",
            @"org.videolan.vlc",
            @"com.colliderli.iina",
            @"com.colliderli.iina-plus"
        ]];
    });
    NSString *bundleID = frontmost.bundleIdentifier ?: @"";
    if ([mediaBundleIDs containsObject:bundleID]) return YES;

    NSString *name = frontmost.localizedName.lowercaseString ?: @"";
    NSArray<NSString *> *mediaNames = @[@"netflix", @"disney", @"quicktime", @"vlc", @"iina"];
    for (NSString *mediaName in mediaNames) {
        if ([name containsString:mediaName]) return YES;
    }
    return [self applicationHasFullscreenWindow:frontmost.processIdentifier];
}

- (BOOL)applicationHasFullscreenWindow:(pid_t)processIdentifier {
    CFArrayRef copied = CGWindowListCopyWindowInfo(
        kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements,
        kCGNullWindowID
    );
    if (!copied) return NO;
    NSArray<NSDictionary *> *windows = CFBridgingRelease(copied);
    for (NSDictionary *window in windows) {
        if ([window[(id)kCGWindowOwnerPID] intValue] != processIdentifier) continue;
        if ([window[(id)kCGWindowLayer] integerValue] != 0) continue;
        CGRect bounds = CGRectZero;
        if (!CGRectMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)window[(id)kCGWindowBounds], &bounds)) continue;
        for (NSScreen *screen in NSScreen.screens) {
            NSSize size = screen.frame.size;
            if (bounds.size.width >= size.width * 0.98 && bounds.size.height >= size.height * 0.98) {
                return YES;
            }
        }
    }
    return NO;
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

- (void)scheduleNextWellnessFrom:(NSTimeInterval)now {
    self.nextWellnessAt = now + MMWellnessInterval;
}

- (void)scheduleNextRollFrom:(NSTimeInterval)now {
    self.nextRollAt = now + MMRandom(MMRollIntervalMinimum, MMRollIntervalMaximum);
}

- (void)maybePlayScheduledRoll:(NSTimeInterval)now {
    if (now < self.nextRollAt) return;
    if (self.petHidden || self.paused || self.cinemaMode) {
        [self scheduleNextRollFrom:now];
        return;
    }

    NSTimeInterval secondsSinceInput = CGEventSourceSecondsSinceLastEventType(
        kCGEventSourceStateCombinedSessionState,
        kCGAnyInputEventType
    );
    BOOL recentlyActive = isfinite(secondsSinceInput) && secondsSinceInput >= 0 && secondsSinceInput < MMWorkActivityWindow;
    if (!recentlyActive) {
        [self scheduleNextRollFrom:now];
        return;
    }

    if (self.focusProtected || self.dragging || self.dropping || self.edgeRetreating ||
        self.edgeHidden || self.edgeEmerging || self.parkedEdge != 0 ||
        self.bubblePanel.visible || self.wellnessReminderActive) return;
    if (self.mode != MMPetModeIdle && self.mode != MMPetModeReview) return;

    [self scheduleNextRollFrom:now];
    MMPetMode scheduledMode = arc4random_uniform(2) == 0 ? MMPetModeBelly : MMPetModeRoll;
    [self enterMode:scheduledMode duration:MMActionDuration(scheduledMode)];
}

- (void)maybeShowWellnessReminder:(NSTimeInterval)now {
    if (now < self.nextWellnessAt || self.wellnessReminderActive) return;
    if (self.petHidden || self.paused) {
        [self scheduleNextWellnessFrom:now];
        return;
    }

    NSTimeInterval secondsSinceInput = CGEventSourceSecondsSinceLastEventType(
        kCGEventSourceStateCombinedSessionState,
        kCGAnyInputEventType
    );
    BOOL activelyWorking = isfinite(secondsSinceInput) && secondsSinceInput >= 0 && secondsSinceInput < MMWorkActivityWindow;
    if (!activelyWorking || self.cinemaMode || [self frontmostAppNeedsQuietScreen]) {
        [self scheduleNextWellnessFrom:now];
        return;
    }

    // Recent typing temporarily hides the pet. Keep this reminder pending until
    // the user has been quiet for three seconds, so the bubble never covers typing.
    if (self.focusProtected || self.dragging || self.bubblePanel.visible) return;
    [self showWellnessReminderAt:now];
}

- (void)showWellnessReminderAt:(NSTimeInterval)now {
    self.wellnessReminderActive = YES;
    self.wellnessReturnEdge = (self.edgeHidden || self.edgeRetreating) ? self.parkedEdge : 0;
    if (self.wellnessReturnEdge != 0) [self clearEdgeStateAndReveal];
    [self noteInteraction];
    [self.panel orderFrontRegardless];
    [self enterMode:MMPetModeWave duration:2.4];
    NSArray<NSString *> *messages = MMWellnessMessages();
    NSString *message = messages[arc4random_uniform((uint32_t)messages.count)];
    [self showBubbleMessage:message duration:MMWellnessDisplayDuration];
    [self scheduleNextWellnessFrom:now];
}

- (void)finishWellnessReminder {
    if (!self.wellnessReminderActive) return;
    self.wellnessReminderActive = NO;
    NSInteger returnEdge = self.wellnessReturnEdge;
    self.wellnessReturnEdge = 0;
    if (returnEdge == 0 || self.petHidden) return;
    self.parkedEdge = returnEdge;
    [self beginEdgeRetreat];
}

- (void)showRandomJoke {
    NSArray<NSString *> *jokes = MMColdJokes();
    NSString *message = jokes[arc4random_uniform((uint32_t)jokes.count)];
    [self showBubbleMessage:message duration:MMJokeDisplayDuration];
    NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    [self scheduleNextJokeFrom:now];
}

- (void)showBubbleMessage:(NSString *)message duration:(NSTimeInterval)duration {
    self.bubbleView.message = message;
    [self updateBubblePosition];
    [self.bubblePanel orderFrontRegardless];
    NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    self.bubbleHideAt = now + duration;
}

- (void)hideBubble {
    [self.bubblePanel orderOut:nil];
    self.bubbleHideAt = 0;
    [self finishWellnessReminder];
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
@property(nonatomic, strong) NSMenuItem *cinemaItem;
@end

@implementation MMAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    NSURL *atlasURL = [NSBundle.mainBundle URLForResource:@"spritesheet" withExtension:@"webp"];
    NSImage *atlas = atlasURL ? [[NSImage alloc] initWithContentsOfURL:atlasURL] : nil;
    NSURL *actionAtlasURL = [NSBundle.mainBundle URLForResource:@"video-actions" withExtension:@"webp"];
    NSImage *actionAtlas = actionAtlasURL ? [[NSImage alloc] initWithContentsOfURL:actionAtlasURL] : nil;
    if (!atlas || !actionAtlas) {
        NSAlert *alert = [NSAlert new];
        alert.messageText = @"妹妹没有找到她的动画图集";
        alert.informativeText = @"请确认 spritesheet.webp 和 video-actions.webp 位于应用 Resources 目录。";
        [alert runModal];
        [NSApp terminate:nil];
        return;
    }

    self.controller = [[MMPetController alloc] initWithAtlas:atlas actionAtlas:actionAtlas];
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
    NSMenuItem *actionsItem = [[NSMenuItem alloc] initWithTitle:@"选择妹妹的动作" action:nil keyEquivalent:@""];
    NSMenu *actionsMenu = [NSMenu new];
    [actionsMenu addItem:[self item:@"歪头杀" action:@selector(playCute:) key:@""]];
    [actionsMenu addItem:[self item:@"吃饭" action:@selector(playEat:) key:@""]];
    [actionsMenu addItem:[self item:@"打滚" action:@selector(playRoll:) key:@""]];
    [actionsMenu addItem:[self item:@"等待" action:@selector(playWaiting:) key:@""]];
    [actionsMenu addItem:[self item:@"开机启动" action:@selector(playStartup:) key:@""]];
    [actionsMenu addItem:[self item:@"一脸期待" action:@selector(playExpectant:) key:@""]];
    actionsItem.submenu = actionsMenu;
    [menu addItem:actionsItem];
    [menu addItem:[self item:@"妹妹，讲个冷笑话" action:@selector(tellJoke:) key:@"j"]];
    self.cinemaItem = [self item:@"开启观影模式" action:@selector(toggleCinemaMode:) key:@"m"];
    [menu addItem:self.cinemaItem];

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
    self.controller.onCinemaModeChanged = ^(BOOL enabled) {
        weakSelf.cinemaItem.title = enabled ? @"退出观影模式" : @"开启观影模式";
        weakSelf.cinemaItem.state = enabled ? NSControlStateValueOn : NSControlStateValueOff;
    };
}

- (NSMenuItem *)item:(NSString *)title action:(SEL)action key:(NSString *)key {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:key];
    item.target = self;
    return item;
}

- (void)bringPet:(id)sender { [self.controller bringToMouse]; }
- (void)playWithPet:(id)sender { [self.controller playNow]; }
- (void)playCute:(id)sender { [self.controller playMode:MMPetModeCute]; }
- (void)playEat:(id)sender { [self.controller playMode:MMPetModeEat]; }
- (void)playRoll:(id)sender { [self.controller playMode:MMPetModeRoll]; }
- (void)playWaiting:(id)sender { [self.controller playMode:MMPetModeIdle]; }
- (void)playStartup:(id)sender { [self.controller playMode:MMPetModeStartup]; }
- (void)playExpectant:(id)sender { [self.controller playMode:MMPetModeExpectant]; }
- (void)tellJoke:(id)sender { [self.controller tellJokeNow]; }
- (void)toggleCinemaMode:(id)sender { [self.controller toggleCinemaMode]; }
- (void)togglePause:(id)sender { [self.controller togglePause]; }
- (void)toggleVisibility:(id)sender { [self.controller toggleVisibility]; }
- (void)quit:(id)sender { [NSApp terminate:nil]; }

@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if ([NSProcessInfo.processInfo.arguments containsObject:@"--print-pet-size"]) {
            CGFloat width = MMDesktopPetWidth();
            printf("%.0fx%.2f\n", width, width * 208.0 / 192.0);
            return 0;
        }
        if ([NSProcessInfo.processInfo.arguments containsObject:@"--print-behavior-config"]) {
            printf("single_instance=true fixed_pet_width=97 enlarged_action_scale=1.5-1.8 walk_action_scale=1.5 roll_action_scale=1.8 enlarged_actions=walk-left-walk-right-roll walk_fps=5.0 walk_speed=42 idle_fps=1.4 play_fps=1.5 custom_action_fps=1.4-5.0 custom_action_rows=11-18 custom_action_source=keyed-live-video video_actions=head-tilt-eating-roll-waiting-startup-walk-left-walk-right-expectant illustrated_fallback=false action_transition=tail-to-head-crossfade transition_seconds=0.62 endpoint_completion=entry-hold-exit-hold-clamped-last-frame double_click=cold-joke petting=eating petting_distance_px=84 petting_cooldown_seconds=12 automatic_behavior=calm automatic_roll=periodic roll_interval_seconds=480-1080 roll_active_only=true corner_hide_seconds=300 hover_reveal=eating-to-corner focus_protection=typing-fullscreen-media cinema_mode=manual wellness_interval_seconds=3600 wellness_display_seconds=10 work_active_window_seconds=300 right_click_quit=temporary left_source=keyed-live-video right_source=keyed-live-video-with-real-tail-completion approach_trigger=expectant upward_drag=expectant drop_action=expectant\n");
            return 0;
        }
        NSApplication *app = NSApplication.sharedApplication;
        MMAppDelegate *delegate = [MMAppDelegate new];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
