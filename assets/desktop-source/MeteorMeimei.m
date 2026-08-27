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
        case MMPetModeIdle:      return (MMAnimation){0, 6, 4.5};
        case MMPetModeWalkRight: return (MMAnimation){1, 8, 9.0};
        case MMPetModeWalkLeft:  return (MMAnimation){2, 8, 9.0};
        case MMPetModeWave:      return (MMAnimation){3, 4, 5.5};
        case MMPetModeJump:      return (MMAnimation){4, 5, 7.0};
        case MMPetModePlay:      return (MMAnimation){7, 6, 7.0};
        case MMPetModeReview:    return (MMAnimation){8, 6, 5.0};
    }
}

static CGFloat MMRandom(CGFloat minimum, CGFloat maximum) {
    CGFloat unit = (CGFloat)arc4random() / (CGFloat)UINT32_MAX;
    return minimum + (maximum - minimum) * unit;
}

@interface MMPetView : NSView
@property(nonatomic, strong) NSImage *atlas;
@property(nonatomic) NSInteger row;
@property(nonatomic) NSInteger column;
@property(nonatomic, copy) void (^onClick)(void);
@property(nonatomic, copy) void (^onDrag)(NSPoint point);
@property(nonatomic, copy) void (^onDragEnd)(void);
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

- (void)setRow:(NSInteger)row {
    _row = row;
    self.needsDisplay = YES;
}

- (void)setColumn:(NSInteger)column {
    _column = column;
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
    [self.atlas drawInRect:self.bounds
                  fromRect:source
                 operation:NSCompositingOperationSourceOver
                  fraction:1.0
            respectFlipped:NO
                     hints:nil];
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

@interface MMPetController : NSObject
@property(nonatomic, strong) MMPetPanel *panel;
@property(nonatomic, strong) MMPetView *petView;
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic) NSTimeInterval lastTick;
@property(nonatomic) MMPetMode mode;
@property(nonatomic) double animationElapsed;
@property(nonatomic) double behaviorRemaining;
@property(nonatomic, strong) NSNumber *targetX;
@property(nonatomic) CGFloat baseY;
@property(nonatomic) BOOL paused;
@property(nonatomic) BOOL petHidden;
@property(nonatomic) BOOL dragging;
@property(nonatomic, copy) void (^onPauseChanged)(BOOL paused);
@property(nonatomic, copy) void (^onVisibilityChanged)(BOOL hidden);
- (instancetype)initWithAtlas:(NSImage *)atlas;
- (void)togglePause;
- (void)toggleVisibility;
- (void)playNow;
- (void)bringToMouse;
- (void)dragFinished;
@end

@implementation MMPetController

static const CGFloat MMPetWidth = 156;
static const CGFloat MMPetHeight = 169;

- (instancetype)initWithAtlas:(NSImage *)atlas {
    self = [super init];
    if (self) {
        NSRect frame = NSMakeRect(0, 0, MMPetWidth, MMPetHeight);
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

        __weak typeof(self) weakSelf = self;
        _petView.onClick = ^{ [weakSelf playNow]; };
        _petView.onDrag = ^(NSPoint point) { [weakSelf dragTo:point]; };
        _petView.onDragEnd = ^{ [weakSelf dragFinished]; };

        [self placeNearMouse];
        [_panel orderFrontRegardless];
        [self enterMode:MMPetModeIdle duration:1.2];
        _lastTick = NSProcessInfo.processInfo.systemUptime;
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
    if (self.paused) [self enterMode:MMPetModeIdle duration:DBL_MAX];
    else [self chooseNextBehavior:NO];
    if (self.onPauseChanged) self.onPauseChanged(self.paused);
}

- (void)toggleVisibility {
    self.petHidden = !self.petHidden;
    if (self.petHidden) [self.panel orderOut:nil];
    else [self.panel orderFrontRegardless];
    if (self.onVisibilityChanged) self.onVisibilityChanged(self.petHidden);
}

- (void)playNow {
    if (self.petHidden) return;
    self.paused = NO;
    if (self.onPauseChanged) self.onPauseChanged(NO);
    uint32_t choice = arc4random_uniform(3);
    MMPetMode next = choice == 0 ? MMPetModeWave : (choice == 1 ? MMPetModeJump : MMPetModePlay);
    [self enterMode:next duration:(next == MMPetModeJump ? 1.15 : 1.6)];
}

- (void)bringToMouse {
    self.petHidden = NO;
    if (self.onVisibilityChanged) self.onVisibilityChanged(NO);
    [self placeNearMouse];
    [self.panel orderFrontRegardless];
    [self enterMode:MMPetModeWave duration:1.4];
}

- (void)tick:(NSTimer *)timer {
    NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    NSTimeInterval delta = MIN(now - self.lastTick, 0.1);
    self.lastTick = now;
    if (self.paused || self.petHidden) return;
    if (self.dragging) return;

    self.animationElapsed += delta;
    self.behaviorRemaining -= delta;
    MMAnimation animation = MMAnimationForMode(self.mode);
    self.petView.row = animation.row;
    self.petView.column = ((NSInteger)floor(self.animationElapsed * animation.fps)) % animation.frames;

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
    if (self.behaviorRemaining <= 0) [self chooseNextBehavior:NO];
}

- (void)updateWalking:(NSTimeInterval)delta {
    NSScreen *screen = [self currentScreen];
    if (!screen || !self.targetX) {
        [self chooseNextBehavior:NO];
        return;
    }
    CGFloat direction = self.mode == MMPetModeWalkRight ? 1 : -1;
    CGFloat x = self.panel.frame.origin.x + direction * 76 * delta;
    CGFloat minX = NSMinX(screen.visibleFrame);
    CGFloat maxX = NSMaxX(screen.visibleFrame) - MMPetWidth;
    x = MIN(MAX(x, minX), maxX);
    [self.panel setFrameOrigin:NSMakePoint(x, self.baseY)];

    CGFloat destination = self.targetX.doubleValue;
    if ((direction > 0 && x >= destination) || (direction < 0 && x <= destination)) {
        [self chooseNextBehavior:YES];
    }
}

- (void)updateJump {
    double progress = MAX(0, MIN(1, 1 - self.behaviorRemaining / 1.15));
    CGFloat jumpHeight = sin(progress * M_PI) * 72;
    [self.panel setFrameOrigin:NSMakePoint(self.panel.frame.origin.x, self.baseY + jumpHeight)];
}

- (void)chooseNextBehavior:(BOOL)forceRest {
    self.targetX = nil;
    if (forceRest) {
        MMPetMode restful[] = {MMPetModeIdle, MMPetModeWave, MMPetModeReview, MMPetModePlay};
        [self enterMode:restful[arc4random_uniform(4)] duration:MMRandom(1.2, 2.8)];
        return;
    }
    uint32_t roll = arc4random_uniform(100);
    if (roll < 48) [self beginWalk];
    else if (roll < 68) [self enterMode:MMPetModeIdle duration:MMRandom(1.5, 3.8)];
    else if (roll < 80) [self enterMode:MMPetModeWave duration:1.5];
    else if (roll < 90) [self enterMode:MMPetModeJump duration:1.15];
    else if (roll < 96) [self enterMode:MMPetModePlay duration:1.6];
    else [self enterMode:MMPetModeReview duration:1.8];
}

- (void)beginWalk {
    NSScreen *screen = [self currentScreen];
    if (!screen) return;
    self.baseY = NSMinY(screen.visibleFrame) + 6;
    CGFloat minX = NSMinX(screen.visibleFrame);
    CGFloat maxX = NSMaxX(screen.visibleFrame) - MMPetWidth;
    CGFloat currentX = MIN(MAX(self.panel.frame.origin.x, minX), maxX);
    CGFloat minimumDistance = MIN(240, MAX(80, (maxX - minX) * 0.25));
    CGFloat destination = MMRandom(minX, maxX);
    for (NSInteger i = 0; i < 8 && fabs(destination - currentX) < minimumDistance; i++) {
        destination = MMRandom(minX, maxX);
    }
    self.targetX = @(destination);
    CGFloat distance = fabs(destination - currentX);
    MMPetMode walkMode = destination >= currentX ? MMPetModeWalkRight : MMPetModeWalkLeft;
    [self enterMode:walkMode duration:distance / 76 + 0.25];
}

- (void)enterMode:(MMPetMode)mode duration:(double)duration {
    self.mode = mode;
    self.animationElapsed = 0;
    self.behaviorRemaining = duration;
    MMAnimation animation = MMAnimationForMode(mode);
    self.petView.row = animation.row;
    self.petView.column = 0;
    if (mode != MMPetModeJump) {
        [self.panel setFrameOrigin:NSMakePoint(self.panel.frame.origin.x, self.baseY)];
    }
}

- (void)placeNearMouse {
    NSPoint mouse = NSEvent.mouseLocation;
    NSScreen *screen = [self screenContainingPoint:mouse] ?: NSScreen.mainScreen;
    if (!screen) return;
    self.baseY = NSMinY(screen.visibleFrame) + 6;
    CGFloat x = MIN(MAX(mouse.x - MMPetWidth / 2, NSMinX(screen.visibleFrame)), NSMaxX(screen.visibleFrame) - MMPetWidth);
    [self.panel setFrame:NSMakeRect(x, self.baseY, MMPetWidth, MMPetHeight) display:YES];
}

- (void)dragTo:(NSPoint)mouse {
    NSScreen *screen = [self screenContainingPoint:mouse] ?: NSScreen.mainScreen;
    if (!screen) return;
    self.dragging = YES;
    self.targetX = nil;
    self.baseY = NSMinY(screen.visibleFrame) + 6;
    CGFloat x = MIN(MAX(mouse.x - MMPetWidth / 2, NSMinX(screen.visibleFrame)), NSMaxX(screen.visibleFrame) - MMPetWidth);
    [self.panel setFrameOrigin:NSMakePoint(x, self.baseY)];
    self.petView.row = 0;
    self.petView.column = 0;
}

- (void)dragFinished {
    self.dragging = NO;
    self.paused = NO;
    [self enterMode:MMPetModeWave duration:1.2];
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
- (void)togglePause:(id)sender { [self.controller togglePause]; }
- (void)toggleVisibility:(id)sender { [self.controller toggleVisibility]; }
- (void)quit:(id)sender { [NSApp terminate:nil]; }

@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        MMAppDelegate *delegate = [MMAppDelegate new];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
