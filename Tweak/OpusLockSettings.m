/// OpusLock — sección visual en la app (referencia: YTMusicUltimate `Settings.x`).
///
/// YTMU añade un `YTMAccountButton` ("YTMusicUltimate") a
/// `YTMAvatarAccountView -setAccountMenuUpperButtons:lowerButtons:` y al
/// pulsarlo presenta su VC de ajustes modally. Replicamos ese punto de
/// entrada, pero 100% dinámico: clases y selectores se resuelven con
/// `NSClassFromString` + firma verificada, y el botón se construye con
/// `NSInvocation` (la clase no existe en tiempo de compilación).
/// Si YT renombra algo, el hook no se instala y el núcleo sigue intacto.

#import "OpusLockSettings.h"
#import "OpusLock.h"
#import "OpusLockPolicy.h"
#import <objc/runtime.h>

// ---------------------------------------------------------------------------
// Settings VC
// ---------------------------------------------------------------------------

@interface OpusLockSettingsController ()
@property (nonatomic, strong) UITableView *tableView;
@end

@implementation OpusLockSettingsController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"OpusLock";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                      target:self
                                                      action:@selector(close)];
    UITableView *t = [[UITableView alloc] initWithFrame:self.view.bounds
                                                  style:UITableViewStyleGrouped];
    t.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    t.delegate = self;
    t.dataSource = self;
    [self.view addSubview:t];
    self.tableView = t;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData]; // refresca "Último stream"
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)qualitySwitchChanged:(UISwitch *)sw {
    OpusLockSetEnabled(sw.isOn);
    NSIndexPath *stream = [NSIndexPath indexPathForRow:0 inSection:1];
    [self.tableView reloadRowsAtIndexPaths:@[stream]
                          withRowAnimation:UITableViewRowAnimationNone];
}

#pragma mark - Tabla

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    (void)tableView;
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    (void)tableView;
    return section == 0 ? @"OPUSLOCK" : @"STREAM";
}

static NSString *OpusLockLastStreamText(void) {
    NSInteger itag = OpusLockLastItag();
    if (itag < 0) return @"—";
    NSDictionary *info = OpusLockLastInfo() ?: [OpusLockPolicy infoForItag:itag];
    NSString *codec = info[@"codec"];
    if (![codec isKindOfClass:[NSString class]]) codec = @"???";
    NSNumber *kbps = info[@"bitrateKbps"];
    NSString *br = [kbps isKindOfClass:[NSNumber class]]
        ? [NSString stringWithFormat:@"%@k", kbps] : @"?k";
    return [NSString stringWithFormat:@"itag%ld · %@ %@", (long)itag, codec, br];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell =
        [tableView dequeueReusableCellWithIdentifier:@"op"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:@"op"];
    }
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    if (indexPath.section == 0 && indexPath.row == 0) {
        cell.textLabel.text = @"OpusLock";
        cell.detailTextLabel.text =
            [NSString stringWithFormat:@"%@ · Instalado", OpusLockVersion];
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else if (indexPath.section == 0) {
        cell.textLabel.text = @"Forzar máxima calidad";
        cell.detailTextLabel.text = @"774 Opus 256k con fallback";
        UISwitch *sw = [[UISwitch alloc] init];
        sw.on = OpusLockIsEnabled();
        [sw addTarget:self
               action:@selector(qualitySwitchChanged:)
     forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
    } else if (indexPath.row == 0) {
        cell.textLabel.text = @"Último stream";
        cell.detailTextLabel.text = OpusLockLastStreamText();
    } else {
        cell.textLabel.text = @"Cadena de fallback";
        cell.detailTextLabel.text = @"774 › 141 › 251 › 140 › …";
    }
    return cell;
}

@end

// ---------------------------------------------------------------------------
// Botón en el menú de cuenta (menú perfil = mismo sitio que YTMU)
// ---------------------------------------------------------------------------

typedef void (*OpusLockMenuIMP)(id, SEL, id, id);
static OpusLockMenuIMP gOrigMenu = NULL;

static void OpusLockPresentSettings(id menuView) {
    @try {
        SEL vcSel = NSSelectorFromString(@"_viewControllerForAncestor");
        if (![menuView respondsToSelector:vcSel]) return;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id rawVC = [menuView performSelector:vcSel];
#pragma clang diagnostic pop
        if (![rawVC respondsToSelector:@selector(presentViewController:animated:completion:)]) return;
        UIViewController *vc = (UIViewController *)rawVC;
        OpusLockSettingsController *settings = [[OpusLockSettingsController alloc] init];
        UINavigationController *nav =
            [[UINavigationController alloc] initWithRootViewController:settings];
        nav.modalPresentationStyle = UIModalPresentationFullScreen;
        [vc presentViewController:nav animated:YES completion:nil];
    } @catch (__unused NSException *e) { }
}

static void OpusLock_setAccountMenu(id self, SEL _cmd, id upper, id lower) {
    @try {
        Class btnCls = NSClassFromString(@"YTMAccountButton");
        SEL initSel = NSSelectorFromString(@"initWithTitle:identifier:icon:actionBlock:");
        BOOL canBuild = (btnCls != Nil) &&
            [btnCls instancesRespondToSelector:initSel] &&
            [lower isKindOfClass:[NSArray class]];
        if (canBuild) {
            UIImage *icon = [UIImage systemImageNamed:@"waveform"];
            if (!icon) icon = [UIImage systemImageNamed:@"music.note"];
            void (^action)(BOOL) = ^(__unused BOOL finished) {
                OpusLockPresentSettings(self);
            };
            void (^actionCopy)(BOOL) = [action copy];

            NSMethodSignature *sig =
                [btnCls instanceMethodSignatureForSelector:initSel];
            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
            __unsafe_unretained id btnAlloc = [btnCls alloc]; // target es unsafe
            inv.target = btnAlloc;
            inv.selector = initSel;
            NSString *title = @"OpusLock";
            NSString *ident = @"opuslock";
            // Args empiezan en índice 2 (0=self, 1=_cmd).
            [inv setArgument:&title atIndex:2];
            [inv setArgument:&ident atIndex:3];
            [inv setArgument:&icon atIndex:4];
            [inv setArgument:&actionCopy atIndex:5];
            [inv invoke];
            __unsafe_unretained id btn = nil;
            [inv getReturnValue:&btn];

            NSMutableArray *newLower = [(NSArray *)lower mutableCopy];
            if (btn) [newLower addObject:btn];
            gOrigMenu(self, _cmd, upper, newLower);
            return;
        }
    } @catch (__unused NSException *e) { }
    // Fallback: comportamiento original intacto.
    gOrigMenu(self, _cmd, upper, lower);
}

void OpusLockInstallAccountMenuHook(void) {
    @try {
        Class menuCls = NSClassFromString(@"YTMAvatarAccountView");
        SEL sel = NSSelectorFromString(@"setAccountMenuUpperButtons:lowerButtons:");
        if (menuCls == Nil) return;
        Method m = class_getInstanceMethod(menuCls, sel);
        if (!m) return;
        // Firma esperada: self, _cmd, upper, lower (4 args totales).
        if (method_getNumberOfArguments(m) != 4) return;
        gOrigMenu = (OpusLockMenuIMP)method_getImplementation(m);
        const char *types = method_getTypeEncoding(m);
        if (class_addMethod(menuCls, sel, (IMP)OpusLock_setAccountMenu, types)) {
            gOrigMenu = (OpusLockMenuIMP)method_getImplementation(
                class_getInstanceMethod(menuCls, sel));
        } else {
            method_setImplementation(m, (IMP)OpusLock_setAccountMenu);
        }
    } @catch (__unused NSException *e) { }
}
