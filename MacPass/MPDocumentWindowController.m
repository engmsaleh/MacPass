//
//  MPMainWindowController.m
//  MacPass
//
//  Created by Michael Starke on 24.07.12.
//  Copyright (c) 2012 HicknHack Software GmbH. All rights reserved.
//

#import "MPDocumentWindowController.h"
#import "MPDocument.h"
#import "MPPasswordInputController.h"
#import "MPEntryViewController.h"
#import "MPPasswordEditViewController.h"
#import "MPToolbarDelegate.h"
#import "MPOutlineViewController.h"
#import "MPOutlineViewDelegate.h"
#import "MPInspectorViewController.h"
#import "MPAppDelegate.h"
#import "MPActionHelper.h"

@interface MPDocumentWindowController () {
@private
  id _firstResponder;
}

@property (retain) IBOutlet NSSplitView *splitView;

@property (retain) NSToolbar *toolbar;

@property (retain) MPPasswordInputController *passwordInputController;
@property (retain) MPPasswordEditViewController *passwordEditController;
@property (retain) MPEntryViewController *entryViewController;
@property (retain) MPOutlineViewController *outlineViewController;
@property (retain) MPInspectorViewController *inspectorViewController;

@property (retain) MPToolbarDelegate *toolbarDelegate;


@end

@implementation MPDocumentWindowController

-(id)init {
  self = [super initWithWindowNibName:@"DocumentWindow" owner:self];
  if( self ) {
    _firstResponder = nil;
    _toolbarDelegate = [[MPToolbarDelegate alloc] init];
    _outlineViewController = [[MPOutlineViewController alloc] init];
    _passwordEditController = [[MPPasswordEditViewController alloc] init];
    _entryViewController = [[MPEntryViewController alloc] init];
    _inspectorViewController = [[MPInspectorViewController alloc] init];
  }
  return self;
}

- (void)dealloc {
  [_toolbar release];
  
  [_passwordInputController release];
  [_entryViewController release];
  [_outlineViewController release];
  [_inspectorViewController release];
  [_creationViewController release];
  
  [_toolbarDelegate release];
  [_splitView release];
  [super dealloc];
}

#pragma mark View Handling
- (void)windowDidLoad
{
  [_entryViewController setupNotifications:self];
  [_inspectorViewController setupNotifications:self];
  
  [super windowDidLoad];
  _toolbar = [[NSToolbar alloc] initWithIdentifier:@"MainWindowToolbar"];
  [self.toolbar setAllowsUserCustomization:YES];
  [self.toolbar setDelegate:self.toolbarDelegate];
  [self.window setToolbar:self.toolbar];
  
  [self.splitView setTranslatesAutoresizingMaskIntoConstraints:NO];
  
  NSView *outlineView = [_outlineViewController view];
  NSView *inspectorView = [_inspectorViewController view];
  NSView *entryView = [_entryViewController view];
  [_splitView addSubview:outlineView];
  [_splitView addSubview:entryView];
  [_splitView addSubview:inspectorView];
  
  [_splitView setHoldingPriority:NSLayoutPriorityDefaultLow+2 forSubviewAtIndex:0];
  [_splitView setHoldingPriority:NSLayoutPriorityDefaultLow+1 forSubviewAtIndex:2];
  
  [[self window] setDelegate:self];
  
  MPDocument *document = [self document];
  if(!document.isDecrypted) {
    [self showPasswordInput];
  }
  else {
    [self showEntries];
  }
}

- (void)_setContentViewController:(MPViewController *)viewController {
  
  NSView *newContentView = nil;
  if(viewController && viewController.view) {
    newContentView = viewController.view;
  }
  NSView *contentView = [[self window] contentView];
  NSView *oldSubView = nil;
  if([[contentView subviews] count] == 1) {
    oldSubView = [contentView subviews][0];
  }
  if(oldSubView == newContentView) {
    return; // View is already present
  }
  [oldSubView removeFromSuperviewWithoutNeedingDisplay];
  [contentView addSubview:newContentView];
  [contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[newContentView]|"
                                                                      options:0
                                                                      metrics:nil
                                                                        views:NSDictionaryOfVariableBindings(newContentView)]];
  
  NSNumber *border = @([[self window] contentBorderThicknessForEdge:NSMinYEdge]);
  [contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[newContentView]-border-|"
                                                                      options:0
                                                                      metrics:NSDictionaryOfVariableBindings(border)
                                                                        views:NSDictionaryOfVariableBindings(newContentView)]];
  
  [contentView layout];
  [viewController updateResponderChain];
  [self.window makeFirstResponder:[viewController reconmendedFirstResponder]];
}

#pragma mark Actions
- (void)performFindPanelAction:(id)sender {
  [self.entryViewController showFilter:sender];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
  return YES;
}

- (BOOL)validateToolbarItem:(NSToolbarItem *)theItem {
  SEL itemAction = [theItem action];
  if( itemAction == [MPActionHelper actionOfType:MPActionLock]) {
    MPDocument *document = [self document];
    BOOL showsNoLockScreen = (nil == [[_passwordInputController view] superview]);
    return showsNoLockScreen && document.isProtected;
  }
  if(itemAction == [MPActionHelper actionOfType:MPActionAddEntry]) {
    return (nil != _entryViewController.activeGroup);
  }
  if(itemAction == [MPActionHelper actionOfType:MPActionDelete]) {
    return (_entryViewController.activeGroup || _entryViewController.selectedEntry);
  }
  if(itemAction == [MPActionHelper actionOfType:MPActionToggleInspector]) {
    return (nil != [_splitView superview]);
  }
  
  return YES;
}

- (void)showPasswordInput {
  if(!self.passwordInputController) {
    self.passwordInputController = [[[MPPasswordInputController alloc] init] autorelease];
  }
  [self _setContentViewController:self.passwordInputController];
  [self.passwordInputController requestPassword];
}

- (void)clearOutlineSelection:(id)sender {
  [self.outlineViewController clearSelection];
}

- (void)editPassword:(id)sender {
  if(!self.passwordEditController) {
    _passwordEditController = [[MPPasswordEditViewController alloc] init];
  }
  [self _setContentViewController:self.passwordEditController];
}

- (void)lock:(id)sender {
  [self showPasswordInput];
}

- (void)createGroup:(id)sender {
  [_outlineViewController createGroup:nil];
}

- (void)toggleInspector:(id)sender {
  NSView *inspectorView = [_inspectorViewController view];
  if([inspectorView superview]) {
    //[inspectorView animator]
    [inspectorView removeFromSuperview];
  }
  else {
    [_splitView addSubview:inspectorView];
  }
}

- (void)showEntries {
  NSView *contentView = [[self window] contentView];
  if(_splitView == contentView) {
    return; // We are displaying the entries already
  }
  if([[contentView subviews] count] == 1) {
    [[contentView subviews][0] removeFromSuperviewWithoutNeedingDisplay];
  }
  [contentView addSubview:_splitView];
  [_splitView adjustSubviews];
  NSView *outlineView = [_outlineViewController view];
  NSView *inspectorView = [_inspectorViewController view];
  NSView *entryView = [_entryViewController view];
  
  NSDictionary *views = NSDictionaryOfVariableBindings(outlineView, inspectorView, entryView, _splitView);
  [self.splitView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[outlineView(>=150,<=250)]-1-[entryView(>=300)]-1-[inspectorView(>=200)]|"
                                                                         options:0
                                                                         metrics:nil
                                                                           views:views]];
  [self.splitView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[outlineView]|"
                                                                         options:0
                                                                         metrics:nil
                                                                           views:views]];
  [self.splitView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[entryView(>=300)]|"
                                                                         options:0
                                                                         metrics:nil
                                                                           views:views]];
  [self.splitView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[inspectorView]|"
                                                                         options:0
                                                                         metrics:nil
                                                                           views:views]];
  NSNumber *border = @([[self window] contentBorderThicknessForEdge:NSMinYEdge]);
  [contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[_splitView]-border-|"
                                                                      options:0
                                                                      metrics:NSDictionaryOfVariableBindings(border)
                                                                        views:views]];
  [contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_splitView]|"
                                                                      options:0
                                                                      metrics:nil
                                                                        views:views]];
  
  [contentView layout];
  [_entryViewController updateResponderChain];
  [_inspectorViewController updateResponderChain];
  [_outlineViewController updateResponderChain];
  [_outlineViewController showOutline];
}

#pragma mark NSWindowDelegate

- (void)windowDidUpdate:(NSNotification *)notification {
  if(_firstResponder != [[self window] firstResponder]) {
    _firstResponder = [[self window] firstResponder];
    if(![_firstResponder isKindOfClass:[NSView class]]) {
      return; // wrong responder
    }
    if( [_firstResponder isDescendantOf:[_entryViewController view]] ) {
      //[_inspectorTabViewController showEntry];
    }
    else if([_firstResponder isDescendantOf:[_outlineViewController view]]) {
      //[_inspectorTabViewController showGroup];
    }
  }
}

#pragma mark Helper
- (NSSearchField *)locateToolbarSearchField {
  for(NSToolbarItem *toolbarItem in [[self.window toolbar] items]) {
    NSView *view = [toolbarItem view];
    if([view isKindOfClass:[NSSearchField class]]) {
      return (NSSearchField *)view;
    }
  }
  return nil;
}


@end
