#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, NSTextFieldDelegate, WKNavigationDelegate>
@property (strong, nonatomic) NSWindow *window;
@property (strong, nonatomic) WKWebView *webView;
@property (strong, nonatomic) NSTextField *urlField;
@property (strong, nonatomic) NSVisualEffectView *toolbar;
@property (strong, nonatomic) NSProgressIndicator *progressIndicator;
@property (strong, nonatomic) NSButton *darkModeToggle;
@property (strong, nonatomic) NSPopover *bookmarksPopover;
@property (strong, nonatomic) NSMutableArray *bookmarks;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self createWindow];
    [self createToolbar];
    [self createWebView];
    [self createProgressIndicator];
    [self initializeBookmarks];
    
    // Load the custom start page powered by startpage.js
    [self loadLocalStartPage];
    
    // Show the window
    [self.window makeKeyAndOrderFront:nil];
}

#pragma mark - UI Setup Methods

- (void)createWindow {
    NSRect frame = NSMakeRect(100, 100, 1400, 900);
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                               styleMask:(NSWindowStyleMaskTitled |
                                                          NSWindowStyleMaskClosable |
                                                          NSWindowStyleMaskResizable |
                                                          NSWindowStyleMaskMiniaturizable |
                                                          NSWindowStyleMaskFullSizeContentView)
                                                 backing:NSBackingStoreBuffered
                                                   defer:NO];
    self.window.title = @"Modern Browser";
    [self.window center];
    self.window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    self.window.backgroundColor = [NSColor blackColor];
    self.window.titlebarAppearsTransparent = YES;
    self.window.titleVisibility = NSWindowTitleHidden;
}

- (void)createToolbar {
    NSRect toolbarFrame = NSMakeRect(0, self.window.frame.size.height - 50, self.window.frame.size.width, 50);
    self.toolbar = [[NSVisualEffectView alloc] initWithFrame:toolbarFrame];
    self.toolbar.material = NSVisualEffectMaterialHUDWindow;
    self.toolbar.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    self.toolbar.state = NSVisualEffectStateActive;
    self.toolbar.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    
    [self createToolbarComponents];
    [self.window.contentView addSubview:self.toolbar];
}

- (void)createToolbarComponents {
    // URL bar
    NSRect urlFieldFrame = NSMakeRect(150, 10, 900, 30);
    self.urlField = [[NSTextField alloc] initWithFrame:urlFieldFrame];
    self.urlField.placeholderString = @"Enter URL or search";
    self.urlField.delegate = self;
    self.urlField.bezeled = NO;
    self.urlField.wantsLayer = YES;
    self.urlField.layer.cornerRadius = 15;
    self.urlField.layer.masksToBounds = YES;
    self.urlField.backgroundColor = [NSColor colorWithWhite:1.0 alpha:0.2];
    self.urlField.textColor = [NSColor whiteColor];
    self.urlField.font = [NSFont systemFontOfSize:16 weight:NSFontWeightMedium];
    
    // Toolbar buttons
    NSArray *buttons = @[
        @{@"image": @"chevron.left", @"action": @"goBack:"},
        @{@"image": @"chevron.right", @"action": @"goForward:"},
        @{@"image": @"arrow.clockwise", @"action": @"refreshPage:"},
        @{@"image": @"xmark", @"action": @"stopLoading:"},
        @{@"image": @"house", @"action": @"goHome:"},
        @{@"image": @"star", @"action": @"toggleBookmarks:"},
        @{@"image": @"moon", @"action": @"toggleDarkMode:"}
    ];
    
    [self addToolbarButtons:buttons startingAtX:10];
    [self.toolbar addSubview:self.urlField];
}

- (void)addToolbarButtons:(NSArray *)buttons startingAtX:(CGFloat)x {
    CGFloat buttonWidth = 40;
    for (NSDictionary *buttonInfo in buttons) {
        NSString *image = buttonInfo[@"image"];
        SEL action = NSSelectorFromString(buttonInfo[@"action"]);
        NSButton *button = [self createButtonWithFrame:NSMakeRect(x, 10, buttonWidth, 30) image:image action:action];
        [self.toolbar addSubview:button];
        x += (buttonWidth + 10);
    }
}

- (void)createWebView {
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.websiteDataStore = [WKWebsiteDataStore defaultDataStore];
    
    // Inject JavaScript for custom start page
    NSString *scriptPath = [[NSBundle mainBundle] pathForResource:@"startpage" ofType:@"js"];
    NSString *scriptContent = [NSString stringWithContentsOfFile:scriptPath encoding:NSUTF8StringEncoding error:nil];
    WKUserScript *userScript = [[WKUserScript alloc] initWithSource:scriptContent injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES];
    [config.userContentController addUserScript:userScript];
    
    NSRect webViewFrame = NSMakeRect(0, 0, self.window.frame.size.width, self.window.frame.size.height - 50);
    self.webView = [[WKWebView alloc] initWithFrame:webViewFrame configuration:config];
    self.webView.autoresizingMask = (NSViewWidthSizable | NSViewHeightSizable);
    self.webView.navigationDelegate = self;
    
    [self.window.contentView addSubview:self.webView];
}

- (void)createProgressIndicator {
    self.progressIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(0, 0, self.window.frame.size.width, 2)];
    self.progressIndicator.style = NSProgressIndicatorStyleBar;
    self.progressIndicator.indeterminate = NO;
    self.progressIndicator.hidden = YES;
    
    [self.window.contentView addSubview:self.progressIndicator];
}

#pragma mark - Button and Action Handling

- (NSButton *)createButtonWithFrame:(NSRect)frame image:(NSString *)imageName action:(SEL)action {
    NSButton *button = [[NSButton alloc] initWithFrame:frame];
    button.image = [NSImage imageWithSystemSymbolName:imageName accessibilityDescription:nil];
    button.target = self;
    button.action = action;
    button.bordered = NO;
    button.wantsLayer = YES;
    button.layer.cornerRadius = 10;
    button.layer.backgroundColor = [[NSColor colorWithWhite:0.2 alpha:0.7] CGColor];
    return button;
}

- (void)loadURL:(NSString *)urlString {
    if (![urlString hasPrefix:@"http://"] && ![urlString hasPrefix:@"https://"]) {
        urlString = [@"https://" stringByAppendingString:urlString];
    }
    NSURL *url = [NSURL URLWithString:urlString];
    if (url) {
        [self.webView loadRequest:[NSURLRequest requestWithURL:url]];
    } else {
        NSLog(@"Invalid URL: %@", urlString);
    }
}

- (void)loadLocalStartPage {
    // Load local HTML file for start page, inject JavaScript through startpage.js
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"startpage" ofType:@"html"];
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    [self.webView loadFileURL:fileURL allowingReadAccessToURL:fileURL];
}

#pragma mark - TextField Delegate

- (void)controlTextDidEndEditing:(NSNotification *)obj {
    NSString *input = self.urlField.stringValue;
    if ([input containsString:@" "] || ![input containsString:@"."]) {
        NSString *searchQuery = [input stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        NSString *searchURL = [NSString stringWithFormat:@"https://www.google.com/search?q=%@", searchQuery];
        [self loadURL:searchURL];
    } else {
        [self loadURL:input];
    }
}

#pragma mark - Navigation Actions

- (void)goBack:(id)sender {
    if ([self.webView canGoBack]) {
        [self.webView goBack];
    }
}

- (void)goForward:(id)sender {
    if ([self.webView canGoForward]) {
        [self.webView goForward];
    }
}

- (void)refreshPage:(id)sender {
    [self.webView reload];
}

- (void)stopLoading:(id)sender {
    [self.webView stopLoading];
}

- (void)goHome:(id)sender {
    [self loadLocalStartPage];
}

#pragma mark - Dark Mode Handling

- (void)toggleDarkMode:(id)sender {
    if ([self.window.appearance.name isEqualToString:NSAppearanceNameDarkAqua]) {
        self.window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
        [self updateDarkModeButton:@"moon"];
    } else {
        self.window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
        [self updateDarkModeButton:@"sun.max"];
    }
}

- (void)updateDarkModeButton:(NSString *)image {
    self.darkModeToggle.image = [NSImage imageWithSystemSymbolName:image accessibilityDescription:nil];
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    self.progressIndicator.doubleValue = 0.0;
    self.progressIndicator.hidden = NO;
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    self.progressIndicator.hidden = YES;
    if (![webView.URL.absoluteString containsString:@"file://"]) {
        self.urlField.stringValue = webView.URL.absoluteString;
    } else {
        self.urlField.stringValue = @"";
    }
    [self updateWindowTitle];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    NSLog(@"Failed to load page: %@", error.localizedDescription);
    self.progressIndicator.hidden = YES;
}

- (void)updateWindowTitle {
    [self.webView evaluateJavaScript:@"document.title" completionHandler:^(id result, NSError *error) {
        if ([result isKindOfClass:[NSString class]]) {
            self.window.title = result;
        }
    }];
}

#pragma mark - Bookmark Management

- (void)initializeBookmarks {
    self.bookmarks = [NSMutableArray array];
    NSArray *savedBookmarks = [[NSUserDefaults standardUserDefaults] arrayForKey:@"Bookmarks"];
    if (savedBookmarks) {
        [self.bookmarks addObjectsFromArray:savedBookmarks];
    }
}

- (void)saveBookmarks {
    [[NSUserDefaults standardUserDefaults] setObject:self.bookmarks forKey:@"Bookmarks"];
}

- (void)addBookmark:(NSString *)url {
    if (![self.bookmarks containsObject:url]) {
        [self.bookmarks addObject:url];
        [self saveBookmarks];
    }
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
