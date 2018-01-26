//
//  MenuManager.m
//  MiddleButtonMenuBar
//
//  Created by John Scott on 25/01/2018.
//  Copyright © 2018 John Scott. All rights reserved.
//

#import "MenuManager.h"

#import <Carbon/Carbon.h>
#import "UIElementUtilities.h"

@interface MenuManager () <NSMenuDelegate>
-(void)handleMiddleButtonPress;
@end

static OSStatus InstallMouseDownHandler(void *userInfo);

OSStatus MouseDownHandler(EventHandlerCallRef nextHandler,EventRef theEvent, void *userData)
{
    NSEvent *anEvent = [NSEvent eventWithEventRef:theEvent];
    //    NSLog(@"%@", anEvent);
    if (anEvent.buttonNumber == 2)
    {
        MenuManager *self = userData;
        [self handleMiddleButtonPress];
    }
    
    
    return noErr;
}

static OSStatus InstallMouseDownHandler(void *userInfo) {
    //create our event type spec for the mouse events
    EventTypeSpec eventTypeM;
    eventTypeM.eventClass = kEventClassMouse;
    eventTypeM.eventKind = kEventMouseDown;
    
    //create a callback for our event to fire in
    EventHandlerUPP handlerFunctionM = NewEventHandlerUPP(MouseDownHandler);
    
    //install the event handler
    OSStatus errM = InstallEventHandler(GetEventMonitorTarget(), handlerFunctionM, 1, &eventTypeM, userInfo, NULL);
    
    //error checking
    if( errM )
    {
        NSLog(@"Error registering mouse handler...%d", errM);
    }
    return errM;
}

@implementation MenuManager
{
    AXUIElementRef _currentElement;
    AXUIElementRef _systemWideElement;
    NSMenu *_currentMenu;
}

-(void)setup
{
    _systemWideElement = AXUIElementCreateSystemWide();
    AXUIElementSetMessagingTimeout( _systemWideElement, 0.3f );
    InstallMouseDownHandler(self);
}

-(void)handleMiddleButtonPress
{
    // The current mouse position with origin at top right.
    NSPoint cocoaPoint = [NSEvent mouseLocation];
    
    // Only ask for the UIElement under the mouse if has moved since the last check.
    
    CGPoint pointAsCGPoint = [UIElementUtilities carbonScreenPointFromCocoaScreenPoint:cocoaPoint];
    
    AXUIElementRef newElement = NULL;
    
    // Ask Accessibility API for UI Element under the mouse
    // And update the display if a different UIElement
    AXError result = AXUIElementCopyElementAtPosition( _systemWideElement, pointAsCGPoint.x, pointAsCGPoint.y, &newElement);
    if (result == kAXErrorSuccess) {
        AXUIElementRef parentElement = newElement;
        while (parentElement)
        {
            newElement = parentElement;
            parentElement = (AXUIElementRef) [UIElementUtilities valueOfAttribute:(NSString*)kAXParentAttribute ofUIElement:newElement];
            
        }
        
        
        newElement = (AXUIElementRef) [UIElementUtilities valueOfAttribute:NSAccessibilityMenuBarAttribute ofUIElement:newElement];
        
        if (newElement)
        {
            [_currentMenu cancelTracking];
            
            if (_currentElement)
            {
                CFRelease(_currentElement);
                _currentElement = nil;
            }
            
            _currentElement = CFRetain(newElement);
            _currentMenu = [self menuForUIElement:newElement];
            
            NSFont *boldFont = [NSFontManager.sharedFontManager convertFont:_currentMenu.font toHaveTrait:NSFontBoldTrait | NSFontCondensedTrait];
            boldFont = [NSFontManager.sharedFontManager convertFont:boldFont toSize:boldFont.pointSize*0.9];
            
            NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc]init] ;
            [paragraphStyle setAlignment:NSTextAlignmentCenter];
            
            NSDictionary *titleAttributes = @{
                                              NSFontAttributeName : boldFont,
                                              NSParagraphStyleAttributeName : paragraphStyle,
                                              NSForegroundColorAttributeName : [NSColor blackColor],
                                              };
            
            _currentMenu.itemArray[1].attributedTitle = [[NSAttributedString alloc] initWithString:_currentMenu.itemArray[1].title
                                                                                         attributes:titleAttributes];
            _currentMenu.itemArray[1].submenu = nil;
            
            [_currentMenu removeItemAtIndex:0];
            dispatch_async(dispatch_get_main_queue(), ^{
                [_currentMenu popUpMenuPositioningItem:nil atLocation:NSEvent.mouseLocation inView:nil];
            });
        }
    }
}

-(id)menuForUIElement:(AXUIElementRef)element
{
    NSString *role = [UIElementUtilities roleOfUIElement:element];
    
    if ([role isEqual:NSAccessibilityMenuBarRole] || [role isEqual:NSAccessibilityMenuRole])
    {
        NSMenu *menu = [NSMenu new];
        
        //        NSLog(@"%@", [self descriptionForUIElement:element]);
        
        //        NSArray
        //        NSLog(@"title %@", [self descriptionForUIElement:[UIElementUtilities valueOfAttribute:NSAccessibilityTitleUIElementAttribute ofUIElement:element]]);
        
        
        for (id foo in [UIElementUtilities valueOfAttribute:NSAccessibilityChildrenAttribute ofUIElement:element])
        {
            id menuItem = [self menuForUIElement:(AXUIElementRef)foo];
            if (menuItem)
            {
                [menu addItem:menuItem];
            }
        }
        menu.delegate = self;
        
        return menu;
    }
    else if ([role isEqual:NSAccessibilityMenuBarItemRole] || [role isEqual:NSAccessibilityMenuItemRole])
    {
        NSString *title = [UIElementUtilities titleOfUIElement:element];
        if ([title hasPrefix:@"Save"])
        {
            //            NSLog(@"%@", [self descriptionForUIElement:element recurseDepth:~0]);
            
        }
        
        //        title = [title stringByReplacingOccurrencesOfString:@"\ufffc " withString:@""];
        
        if (!title.length)
        {
            return [NSMenuItem separatorItem];
        }
        
        NSMenuItem *menuItem = [NSMenuItem new];
        menuItem.representedObject = (id) element;
        menuItem.title = title;
        
        BOOL isEnabled = [[UIElementUtilities valueOfAttribute:NSAccessibilityEnabledAttribute ofUIElement:element] boolValue];
        
        NSArray *subelements = [UIElementUtilities valueOfAttribute:NSAccessibilityChildrenAttribute ofUIElement:element];
        
        NSArray <NSString*>*actionNames = [UIElementUtilities actionNamesOfUIElement:element];
        
        AXUIElementRef primaryElement = (AXUIElementRef) [UIElementUtilities valueOfAttribute:@"AXMenuItemPrimaryUIElement" ofUIElement:element];
        
        //        if (primaryElement)
        //        {
        //            NSLog(@"%@", [self descriptionForUIElement:element recurseDepth:~0]);
        //        }
        //
        NSString *alternativeTitle = [UIElementUtilities titleOfUIElement:primaryElement];
        
        if (alternativeTitle && ![title isEqual:alternativeTitle])
        {
            //            NSLog(@"%@ %@", title, alternativeTitle);
            menuItem.alternate = YES;
            
        }
        
        if (subelements.firstObject)
        {
            menuItem.submenu = [NSMenu new];
        }
        else if (isEnabled && [actionNames containsObject:NSAccessibilityPressAction])
        {
            menuItem.action = @selector(menuItemPressed:);
            menuItem.target = self;
        }
        
        return menuItem;
    }
    else
    {
        //        NSMenuItem *menuItem = [NSMenuItem new];
        //        menuItem.title = [NSString stringWithFormat:@"!!! %@ !!!", role];
        NSLog(@"%@", [self descriptionForUIElement:element recurseDepth:0]);
        //        return menuItem;
    }
    
    return nil;
}

-(void)menuItemPressed:(NSMenuItem*)menuItem
{
    AXUIElementRef element = (AXUIElementRef) menuItem.representedObject;
    [UIElementUtilities performAction:NSAccessibilityPressAction ofUIElement:element];
}

- (void)menuDidClose:(NSMenu *)menu
{
    if (menu == _currentMenu)
    {
        if (_currentElement)
        {
            CFRelease(_currentElement);
            _currentElement = nil;
        }
        _currentMenu = nil;
    }
}

- (void)menu:(NSMenu *)menu willHighlightItem:(nullable NSMenuItem *)menuItem
{
    if (menuItem.submenu && !menuItem.submenu.numberOfItems)
    {
        AXUIElementRef element = (AXUIElementRef) menuItem.representedObject;
        NSArray *subelements = [UIElementUtilities valueOfAttribute:NSAccessibilityChildrenAttribute ofUIElement:element];
        menuItem.submenu = [self menuForUIElement:(AXUIElementRef)subelements.firstObject];
    }
}

-(id)descriptionForUIElement:(AXUIElementRef)element recurseDepth:(NSUInteger)recurseDepth
{
    NSMutableDictionary *description = [NSMutableDictionary new];
    for (NSString *attributeName in [UIElementUtilities attributeNamesOfUIElement:element])
    {
        id value = [UIElementUtilities valueOfAttribute:attributeName ofUIElement:element];
        if (recurseDepth && ![attributeName isEqual:NSAccessibilityParentAttribute])
        {
            if ([value isKindOfClass:NSArray.class])
            {
                NSMutableArray *expandedValues = [NSMutableArray new];
                for (id subvalue in value)
                {
                    id expandedValue = [self descriptionForUIElement:(AXUIElementRef)subvalue recurseDepth:recurseDepth-1];
                    if (expandedValue)
                    {
                        [expandedValues addObject:expandedValue];
                    }
                }
                value = expandedValues;
            }
            else if ([attributeName isEqual:@"AXMenuItemPrimaryUIElement"])
            {
                id expandedValue = [self descriptionForUIElement:(AXUIElementRef)value recurseDepth:MIN(recurseDepth-1, 1)];
                if (expandedValue)
                {
                    value = expandedValue;
                }
                
                
            }
        }
        description[attributeName] = value;
    }
    
    description[@"__actions"] = [UIElementUtilities actionNamesOfUIElement:element];
    description[@"__"] = [NSString stringWithFormat:@"%p", element];
    
    return description;
}

@end
