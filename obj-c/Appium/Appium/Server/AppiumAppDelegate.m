//
//  AppiumAppDelegate.m
//  Appium
//
//  Created by Dan Cuellar on 3/3/13.
//  Copyright (c) 2013 Appium. All rights reserved.
//

#import "AppiumAppDelegate.h"

#import "AppiumInspectorWindowController.h"
#import "AppiumInstallationWindowController.h"
#import "AppiumPreferencesWindowController.h"
#import "AppiumUpdater.h"
#import "NodeInstance.h"
#import "Utility.h"

@implementation AppiumAppDelegate

#pragma mark - Handlers

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// create model
	[self setModel:[AppiumModel new]];
	
    // create main monitor window
    [self setMainWindowController:[[AppiumMonitorWindowController alloc] initWithWindowNibName:@"AppiumMonitorWindow"]];
	_updater = [[AppiumUpdater alloc] initWithAppiumMonitorWindowController:[self mainWindowController]];

    // install anything that's missing
    [self performSelectorInBackground:@selector(install) withObject:nil];
    
}

-(void)applicationWillTerminate:(NSNotification *)notification
{
    [self.model killServer];
}

#pragma mark - Preferences

-(IBAction) displayPreferences:(id)sender
{
	if (_preferencesWindow == nil)
	{
		_preferencesWindow = [[AppiumPreferencesWindowController alloc] initWithWindowNibName:@"AppiumPreferencesWindow"];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(preferenceWindowWillClose:)
													 name:NSWindowWillCloseNotification
												   object:[_preferencesWindow window]];
	}
	
	[_preferencesWindow showWindow:self];
	[[_preferencesWindow window] makeKeyAndOrderFront:self];
}

- (void)preferenceWindowWillClose:(NSNotification *)notification
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowWillCloseNotification object:[_preferencesWindow window]];
	_preferencesWindow = nil;
}

#pragma mark - Inspector

-(IBAction) displayInspector:(id)sender
{
	if (_inspectorWindow == nil)
	{
		_inspectorWindow = [[AppiumInspectorWindowController alloc] initWithWindowNibName:@"AppiumInspectorWindow"];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(inspectorWindowWillClose:)
													 name:NSWindowWillCloseNotification
												   object:[_inspectorWindow window]];
	}
	
	[_inspectorWindow showWindow:self];
	[[_inspectorWindow window] makeKeyAndOrderFront:self];
}

- (void)inspectorWindowWillClose:(NSNotification *)notification
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowWillCloseNotification object:[_inspectorWindow window]];
	_inspectorWindow = nil;
}

#pragma mark - Updates

-(void) install
{
    // check is nodejs, appium, or appium pre-reqs are missing
    NSString *nodeRootPath = [[NSBundle mainBundle] resourcePath];
    BOOL installationRequired = ![NodeInstance instanceExistsAtPath:nodeRootPath];
    installationRequired |= ![NodeInstance packageIsInstalledAtPath:nodeRootPath withName:@"appium"];
    
    if (installationRequired)
    {
        // install software
        AppiumInstallationWindowController *installationWindow = [[AppiumInstallationWindowController alloc] initWithWindowNibName:@"AppiumInstallationWindow"];
        [installationWindow performSelectorOnMainThread:@selector(showWindow:) withObject:self waitUntilDone:YES];
        [[installationWindow window] performSelectorOnMainThread:@selector(makeKeyAndOrderFront:) withObject:self waitUntilDone:YES];
        [[installationWindow messageLabel] performSelectorOnMainThread:@selector(setStringValue:) withObject:@"Installing NodeJS..." waitUntilDone:YES];
        [[self mainWindowController] setNode:[[NodeInstance alloc] initWithPath:nodeRootPath]];
        [[installationWindow messageLabel] performSelectorOnMainThread:@selector(setStringValue:) withObject:@"Installing Appium..." waitUntilDone:YES];
        [[[self mainWindowController] node] installPackage:@"appium" forceInstall:NO];
        [[installationWindow window] performSelectorOnMainThread:@selector(close) withObject:nil waitUntilDone:YES];
		
		NSString *iwdPath = [NSString stringWithFormat:@"%@/submodules/instruments-without-delay/build", [[self.mainWindowController node] pathtoPackage:@"appium"]];
		if (![[NSFileManager defaultManager] fileExistsAtPath:iwdPath])
		{
			NSString *submodulesPath = [NSString stringWithFormat:@"%@/submodules", [[self.mainWindowController node] pathtoPackage:@"appium"]];
			[[installationWindow messageLabel] performSelectorOnMainThread:@selector(setStringValue:) withObject:@"Building \"Instruments Without Delay\"..." waitUntilDone:YES];
			[Utility runTaskWithBinary:@"/bin/sh" arguments:[NSArray arrayWithObjects:@"./build.sh", nil] path:[NSString stringWithFormat:@"%@/%@", submodulesPath, @"instruments-without-delay"]];
		}
    }
    else
    {
        // create node instance
        [[self mainWindowController] setNode:[[NodeInstance alloc] initWithPath:nodeRootPath]];
    }
    
    // show main monitor window
    [[self mainWindowController] performSelectorOnMainThread:@selector(showWindow:) withObject:self waitUntilDone:YES];
    [[[self mainWindowController] window] performSelectorOnMainThread:@selector(makeKeyAndOrderFront:) withObject:self waitUntilDone:YES];

    // check for updates
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"Check For Updates"])
    {
        [self checkForUpdates:nil];
    }
}

-(IBAction)checkForUpdates:(id)sender
{
	[_updater performSelectorInBackground:@selector(checkForUpdates:) withObject:sender];
}

-(void) restart
{
    NSTask *restartTask = [NSTask new];
    [restartTask setLaunchPath:@"/bin/sh"];
    [restartTask setArguments:[NSArray arrayWithObjects: @"-c",[NSString stringWithFormat:@"sleep 2; open \"%@\"", [[NSBundle mainBundle] bundlePath] ], nil]];
    [restartTask launch];
    [[NSApplication sharedApplication] terminate:nil];
}

@end
