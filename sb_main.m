#import <AppKit/NSRunningApplication.h>
#import <AppKit/NSGraphicsContext.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSEvent.h>
#import <Foundation/NSAutoreleasePool.h>
#import <ApplicationServices/ApplicationServices.h>
#include <Carbon/Carbon.h>
#include <stdio.h>
#include <sys/types.h>
#include <pthread.h>
#include <stdint.h>
#import <mach/mach_time.h>
#include <dispatch/queue.h>
#define SKWTimestamp(x) (((double)mach_absolute_time(x)) * 1.0e-09)
#include "cg_priv.h"
#include "sb_ui.h"

int active = 0;
CGSConnectionID cid;
CFMachPortRef tap;
CFMutableArrayRef windows;

void get_window_list(void) {
    CFArrayRef allwnd = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements,0);

    windows = CFArrayCreateMutableCopy(NULL, CFArrayGetCount(allwnd), allwnd);
    int i;
    CFNumberRef layer;
    long layernum;
    int remove;
    for (i=CFArrayGetCount(allwnd)-1; i>=0; i--) {
        remove = 0;

        CFStringRef title = CFDictionaryGetValue(CFArrayGetValueAtIndex(windows, i), kCGWindowName);
        if (!title || CFStringGetLength(title) < 1)
            remove = 1;

        CFNumberRef layer = CFDictionaryGetValue(CFArrayGetValueAtIndex(windows, i), kCGWindowLayer);
        long layernum;
        CFNumberGetValue(layer, kCFNumberLongType, &layernum);
        if (layernum > 10)
            remove = 1;

        if (remove)
            CFArrayRemoveValueAtIndex(windows, i);
    }
}

long wid_for_window(int index) {
    long wid;
    CFNumberRef widref = CFDictionaryGetValue(CFArrayGetValueAtIndex(windows, index), kCGWindowNumber);
    CFNumberGetValue(widref, kCFNumberLongType, &wid);
    return wid;
}

extern void CGSSetDebugOptions(long int options);
extern void    CGEventSetWindowLocation(CGEventRef evt, CGWindowID wid, CGPoint at);
void activate_window(int index) {
    CFDictionaryRef winfo = CFArrayGetValueAtIndex(windows, index);

    int sel_wid = wid_for_window(index);
    int top_wid = wid_for_window(0);
    
    CFNumberRef pidref = CFDictionaryGetValue(winfo, kCGWindowOwnerPID);
    long pid;
    CFNumberGetValue(pidref, kCFNumberLongType, &pid);
    
    ProcessSerialNumber psn, mypsn;
    GetProcessForPID(pid, &psn);
    GetCurrentProcess(&mypsn);

    CGSOrderWindow(cid, sel_wid, kCGSOrderAbove, top_wid);


    CGRect bounds;
    CGRectMakeWithDictionaryRepresentation(CFDictionaryGetValue(winfo, kCGWindowBounds), &bounds);
    CGPoint click_at = CGPointMake(1,1);
    
    CGEventSourceRef eventSource = CGEventSourceCreate(kCGEventSourceStatePrivate);

    CGEventRef click = CGEventCreateMouseEvent(eventSource, kCGEventLeftMouseDown, click_at, kCGMouseButtonLeft);
    CGEventSetWindowLocation(click, sel_wid, click_at);
    CGEventSetIntegerValueField(click, kCGWindowNumberField, sel_wid);

    CGEventPostToPSN(&psn, click);
    CFRelease(click);

    click = CGEventCreateMouseEvent(eventSource, kCGEventLeftMouseUp, click_at, kCGMouseButtonLeft);
    CGEventSetWindowLocation(click, sel_wid, click_at);
    CGEventSetIntegerValueField(click, kCGWindowNumberField, sel_wid);
    CGEventPostToPSN(&psn, click); 
    CFRelease(click);
    CFRelease(eventSource);

    CPSSetFrontProcess(&psn);
}

void post_ui_callback(int type) {
    int selected;
    if (type==uiShow)
        get_window_list();

    ui_callback(type);
    if (type==uiHide) {
        selected = ui_callback(uiGetSel);
        if (selected)
            activate_window(selected);
        CFRelease(windows);
    }
}

#define ui_callback(val) dispatch_sync(dispatch_get_main_queue(), ^{post_ui_callback(val);})

CGEventRef key_callback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *ctx) {
    if (type==kCGEventTapDisabledByTimeout || type & 0x80000000) {
        dispatch_sync(dispatch_get_main_queue(), ^{fprintf(stderr, "reenabling tap\n"); CGEventTapEnable(tap, true);});
        return 0;
    }

    int flags = CGEventGetFlags(event);
    int alt_dn = flags & kCGEventFlagMaskAlternate;
    if (active && type == kCGEventFlagsChanged && !alt_dn) {
        active = 0;
        ui_callback(uiHide);
        return event;
    }

    if (kVK_Tab != CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode))
        return event;
    
    if (!active) {
        if (type != kCGEventKeyDown || !alt_dn)
            return event;
        active = 1;
        ui_callback(uiShow);
        return 0;
    }
    
    if (flags & kCGEventFlagMaskShift)
        ui_callback(uiPrev);
    else
        ui_callback(uiNext);
    return 0;
}

void * on_init(void *arg) {
    sleep(1);
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    unsetenv("DYLD_INSERT_LIBRARIES");
    cid = _CGSDefaultConnection();

    ui_init();

    tap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, 0, CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(kCGEventFlagsChanged), key_callback, 0);
    if (!tap)
        fprintf(stderr, "failed to create tap\n");

    CFRunLoopSourceRef runsrc;
    runsrc = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0);

    CFRunLoopAddSource(CFRunLoopGetCurrent(), runsrc, kCFRunLoopCommonModes);

    CFRunLoopRun();

    fprintf(stderr, "FELL OUT OF MAIN LOOP\n");
    CGEventTapEnable(tap, 0);
    
    ui_release();
    [pool drain];
}
void on_load(void) {
    pthread_t thread;
    pthread_create(&thread, 0, on_init, 0);
}
