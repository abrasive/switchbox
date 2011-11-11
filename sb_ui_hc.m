#import <AppKit/NSRunningApplication.h>
#import <AppKit/NSGraphicsContext.h>
#import <AppKit/NSImage.h>
#import <Foundation/NSAutoreleasePool.h>
#import <ApplicationServices/ApplicationServices.h>
#include <Carbon/Carbon.h>
#include <stdio.h>
#include <sys/types.h>
#include <stdint.h>
#include "cg_priv.h"
#include "sb_ui.h"

#define fFontFace "FixedsysExcelsiorIIIb"
#define fFontSize (16)

#define CSC(c) ((c*1.0)/255.0)
#define COLOR(r,g,b) CSC(r), CSC(g), CSC(b)

#define cBG COLOR(0,0,0)
#define cBorder COLOR(250,0,0)
#define cTxt COLOR(255,255,255)

#define cSelBox COLOR(200,200,200)
#define cSelTxt COLOR(0,0,0)

#define sOuterBorder (5)
#define sInnerBorder (3)
#define sMargin      (10)
#define sIconSize    (16)
#define sRowPitch    (sIconSize+5)
#define sRowTextOff  (20)

#define inXMin (sOuterBorder+sInnerBorder+sMargin)
#define inYMin (sOuterBorder+sInnerBorder+sMargin)


void new_window(CGWindowID *pwid, CGContextRef *pctx, int width, int height) {
    CGDirectDisplayID disp = CGMainDisplayID();
    int xpos, ypos;
    xpos = (CGDisplayPixelsWide(disp) - width)/2;
    ypos = (CGDisplayPixelsHigh(disp) - height)/2;

    CGRect rect = CGRectMake(xpos,ypos,width,height);
    CGSRegionRef reg;
    CGWindowID wid;
    CGContextRef ctx;
    CGSNewRegionWithRect(&rect, &reg);
    CGSNewWindow(cid, 2, 0.0, 0.0, reg, &wid);
    *pwid = wid;
    CGSReleaseRegion(reg);
    ctx = CGWindowContextCreate(cid, wid, 0);
    *pctx = ctx;

    CGSWindowTag tags[2];
    tags[0] = tags[1] = CGSTagNoShadow | CGSTagSticky;
    CGSSetWindowTags(cid, wid, tags, 32);
    CGSSetWindowLevel(cid, wid, 32);

    CGContextSetShouldAntialias(ctx, false);

    CGContextErase(ctx);
    CGContextSetRGBFillColor(ctx, cBG, 1.0);
    rect = CGRectMake(0,0,width,height);
    CGContextFillRect(ctx, rect);

    CGContextFlush(ctx);
}

NSMutableDictionary *icns;
NSImage *icon_for_pid(pid_t pid) {
    NSNumber *key = [NSNumber numberWithLong: pid];
    NSImage *icn = [icns objectForKey: key];
    if (!icn) {
        icn = [[NSRunningApplication runningApplicationWithProcessIdentifier: pid] icon];
        if (!icn)
            return icn;
        [icns setObject: icn forKey: key];
    }
    return icn;
}

void draw_icon(CGContextRef ctx, pid_t pid, int row) {
    NSImage *icn;
    icn = icon_for_pid(pid);
    
    NSGraphicsContext *gctx = [NSGraphicsContext graphicsContextWithGraphicsPort: ctx flipped: false];

    NSRect icnrect = NSMakeRect(0,0,sIconSize,sIconSize);
    CGImageRef cgicn = [icn CGImageForProposedRect: &icnrect context: gctx hints: nil];
    CGContextDrawImage(ctx, CGRectMake(inXMin, inYMin + row*sRowPitch + (sRowPitch-sIconSize)/2, sIconSize, sIconSize), cgicn);
}

CTFontRef ui_fnt;
int ui_rows;
int draw_icon_row;
void draw_window_icon(CFDictionaryRef val, void *ctx) {
    CFNumberRef pidref = CFDictionaryGetValue(val, kCGWindowOwnerPID);
    long pid;
    CFNumberGetValue(pidref, kCFNumberLongType, &pid);
    draw_icon(ctx, pid, draw_icon_row--);
}

void draw_borders(CGContextRef ctx, int width, int height) {
    CGRect rect;
    CGContextSetRGBFillColor(ctx, cBorder, 1.0);
    rect = CGRectMake(sOuterBorder, sOuterBorder,width-2*sOuterBorder,sInnerBorder);
    CGContextFillRect(ctx, rect);
    //rect = CGRectMake(sOuterBorder, sOuterBorder,sInnerBorder, height-2*sOuterBorder);
    //CGContextFillRect(ctx, rect);
    //rect = CGRectMake(width-sOuterBorder-sInnerBorder, sOuterBorder,sInnerBorder, height-2*sOuterBorder);
    //CGContextFillRect(ctx, rect);
    rect = CGRectMake(sOuterBorder, height-sOuterBorder-sInnerBorder,width-2*sOuterBorder, sInnerBorder);
    CGContextFillRect(ctx, rect);
}

void draw_text(CGContextRef ctx, CTFontRef fnt, CFStringRef cftext, int x, int y, int width, float r, float g, float b) {
    CGContextSaveGState(ctx);
    CGRect rect = CGRectMake(x,y-5,width,fFontSize+10);
    CGContextClipToRect(ctx, rect);
   
    CGContextSetRGBFillColor  (ctx, r, g, b, 1.0);

    int i;
    UniChar uchars[512];
    int nuchars = CFStringGetLength(cftext);
    if (nuchars > 512)
        nuchars = 512;
    CFStringGetCharacters(cftext, CFRangeMake(0, nuchars), uchars);
    CGGlyph glyphs[512];
    CTFontGetGlyphsForCharacters(fnt, uchars, glyphs, nuchars);
    CGSize advs[512];
    CTFontGetAdvancesForGlyphs(fnt, kCTFontDefaultOrientation, glyphs, advs, nuchars);

    CGContextSelectFont (ctx, fFontFace, fFontSize, kCGEncodingMacRoman);
    CGContextSetFontSize(ctx, fFontSize);
    CGContextSetTextPosition(ctx, x, y);
    CGContextShowGlyphsWithAdvances(ctx, glyphs, advs, nuchars);
    CGContextRestoreGState(ctx);
}

void draw_box_title(CGContextRef ctx, int selected, int width, float boxr, float boxg, float boxb, float txtr, float txtg, float txtb) {
    CFDictionaryRef wnd;
    wnd = CFArrayGetValueAtIndex(windows, selected);

    CGRect rect;
    CGContextSetRGBFillColor(ctx, boxr, boxg, boxb, 1.0);
    rect = CGRectMake(sOuterBorder+sInnerBorder, sRowPitch*(ui_rows - selected - 1) + inYMin, width-2*(sOuterBorder+sInnerBorder), sRowPitch);
    CGContextFillRect(ctx, rect);

    draw_icon_row = ui_rows - selected - 1;
    draw_window_icon(wnd, ctx);

    CFStringRef title;
    title = CFDictionaryGetValue(wnd, kCGWindowName);

    draw_text(ctx, ui_fnt, title, inXMin + sRowPitch, sRowPitch*(ui_rows-selected-1)+inYMin+(sRowPitch-16)/2+3, width-2*inYMin-sRowPitch, txtr, txtg, txtb);
}

void ui_init(void) {
    ui_fnt = CTFontCreateWithName(CFSTR(fFontFace), fFontSize, NULL);
}
void ui_release(void) {
    CFRelease(ui_fnt);
}

int ui_callback(ui_call action) {
    static int showing = 0;

    static CGContextRef ctx;
    static CGWindowID wid;
    static int selected = 0;
    static int nwind = 0, width, height;
    int i, last;

    last = selected;

    if (action == uiGetSel)
        return selected;

    if (action == uiShow && !showing) {
        showing = 1;
        nwind = CFArrayGetCount(windows);
        ui_rows = nwind;
        
        width = 600;
        height = sRowPitch * ui_rows + 2*(sOuterBorder+sInnerBorder+sMargin);
        new_window(&wid, &ctx, width, height);

        draw_borders(ctx, width, height);
        icns = [[NSMutableDictionary alloc] init];

        selected = 1;
        last = selected;

        for (i=0; i<ui_rows; i++)
            draw_box_title(ctx, i, width, cBG, cTxt);
        draw_box_title(ctx, 1, width, cSelBox, cSelTxt);


        CGSOrderWindow(cid, wid, kCGSOrderAbove, 0);

    }
    if (action == uiHide && showing) {
        CGSReleaseWindow(cid, wid);
        [icns release];
        showing = 0;
        return 0;
    }

    if (action == uiNext) {
        selected++;
        if (selected > nwind-1)
            selected = 0;
    } else if (action == uiPrev) {
        selected--;
        if (selected < 0)
            selected = nwind-1;
    }

    if (last != selected) {
        draw_box_title(ctx, selected, width, cSelBox, cSelTxt);
        draw_box_title(ctx, last, width, cBG, cTxt);
    }

    CGContextFlush(ctx);
    return 0;
}
