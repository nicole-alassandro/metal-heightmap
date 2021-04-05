// Copyright (C) 2021  Nicole Alassandro

// This program is free software: you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by the Free
// Software Foundation, either version 3 of the License, or (at your option)
// any later version.

// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
// more details.

// You should have received a copy of the GNU General Public License along
// with this program.  If not, see <http://www.gnu.org/licenses/>.

@interface AppDelegate : NSObject<NSApplicationDelegate>
@end

@implementation AppDelegate{
    NSWindow* _window;
    Renderer* _renderer;
    MTKView*  _view;
}

-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)sender
{
    return YES;
}

-(void)applicationWillFinishLaunching:(NSNotification*)notification
{
    [NSApp activateIgnoringOtherApps:YES];

    {
        NSMenu     * menuBar  = [NSMenu new];
        NSMenuItem * menuItem = [NSMenuItem new];
        NSMenu     * fileMenu = [NSMenu new];
        NSMenuItem * quitItem = [
            [NSMenuItem alloc]
            initWithTitle:@"Quit"
            action:@selector(terminate:)
            keyEquivalent:@"q"
        ];

        [menuBar addItem:menuItem];
        [menuItem setSubmenu:fileMenu];
        [fileMenu addItem:quitItem];
        NSApp.mainMenu = menuBar;
    }

    _window = [
        [NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 512, 512)
        styleMask:NSWindowStyleMaskTitled
                 |NSWindowStyleMaskClosable
        backing:NSBackingStoreBuffered
        defer:NO
    ];

    _window.title = [[NSProcessInfo processInfo] processName];
    [_window cascadeTopLeftFromPoint:NSMakePoint(20, 20)];
    [_window makeKeyAndOrderFront:nil];

    _view = [
        [MTKView alloc]
        initWithFrame:NSMakeRect(0, 0, 512, 512)
        device:MTLCreateSystemDefaultDevice()
    ];
    _renderer = [[Renderer alloc] initWithView:_view];
    _view.delegate = _renderer;
    _window.contentView = _view;
}
@end
