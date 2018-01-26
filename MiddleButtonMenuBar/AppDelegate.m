//
//  AppDelegate.m
//  MiddleButtonMenuBar
//
//  Created by John Scott on 25/01/2018.
//  Copyright © 2018 John Scott. All rights reserved.
//

#import "AppDelegate.h"
#import "MenuManager.h"

@interface AppDelegate () <NSMenuDelegate>

@property (nonatomic, strong) MenuManager *menuManager;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.menuManager = [MenuManager new];
    [self.menuManager setup];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
}


@end
