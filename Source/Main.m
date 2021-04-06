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


#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <GLKit/GLKit.h>

#include <math.h>

#include "defs.h"
#include "Renderer.m"
#include "AppDelegate.m"

int main(int argc, char const *argv[])
{
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setDelegate:[AppDelegate new]];
        return NSApplicationMain(argc, argv);
    }
}
