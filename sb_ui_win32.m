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

#define CSC(c) ((c*1.0)/255.0)
#define COLOR(r,g,b) CSC(r), CSC(g), CSC(b)

#define cBevHi COLOR(255,255,255)
// newer, more neutral grey
#define cBG COLOR(205,205,194)
//#define cBG COLOR(202,198,187)
#define cBevLo COLOR(109,109,109)
#define cShad COLOR(49,49,49)
//#define cBox COLOR(9,18,92)
#define cBox COLOR(10,21,91)

#define MAXCOLS (7)

void cg_lines(CGContextRef ctx, float x0, float y0, float x1, float y2) {
    CGContextBeginPath(ctx);
    CGContextMoveToPoint(ctx, x0, y0);
    CGContextAddLineToPoint(ctx, x1, y0);
    CGContextAddLineToPoint(ctx, x1, y2);
    CGContextStrokePath(ctx);
}

void cg_box(CGContextRef ctx, float x0, float y0, float x1, float y1) {
    CGContextBeginPath(ctx);
    CGContextMoveToPoint(ctx, x0, y0);
    CGContextAddLineToPoint(ctx, x0, y1);
    CGContextAddLineToPoint(ctx, x1, y1);
    CGContextAddLineToPoint(ctx, x1, y0);
    CGContextClosePath(ctx);
    CGContextStrokePath(ctx);
}

void shad_box(CGContextRef ctx, int invert, int x0, int y0, int x1, int y1) {
    CGContextSetLineWidth(ctx, 1);
    CGContextSetRGBStrokeColor(ctx, cBevHi, 1.0);
    if (invert)
        cg_lines(ctx, x0, y0, x1, y1);
    else
        cg_lines(ctx, x1-2, y1-1, x0+1, y0+2);
    CGContextSetRGBStrokeColor(ctx, cBevLo, 1.0);
    if (invert)
        cg_lines(ctx, x1-1, y1, x0, y0+1);
    else
        cg_lines(ctx, x0+1, y0+1, x1-1, y1-1);
    CGContextSetRGBStrokeColor(ctx, cShad, 1.0);
    if (invert)
        cg_lines(ctx, x1-2, y1-1, x0+1, y0+2);
    else
        cg_lines(ctx, x0, y0, x1, y1);
}

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

void set_text(CGContextRef ctx, CTFontRef fnt, CFStringRef cftext, int width) {
    CGContextSaveGState(ctx);
    CGContextSetRGBFillColor  (ctx, cBG, 1.0);
    CGRect rect = CGRectMake(16,16,width,17);
    CGContextFillRect(ctx, rect);
    CGContextClipToRect(ctx, rect);
   
    CGContextSetRGBFillColor  (ctx, 0.0, 0.0, 0.0, 1.0);

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

    for (i=0; i<nuchars; i++)
        advs[i].width = ceil(advs[i].width-0.45); 
    CGContextSelectFont (ctx, "Tahoma Bold", 11.0, kCGEncodingMacRoman);

    CGContextSetFontSize(ctx, 11.0);
    CGContextSetTextPosition(ctx, 17.0, 19);
    CGContextShowGlyphsWithAdvances(ctx, glyphs, advs, nuchars);
    CGContextRestoreGState(ctx);
}

int last_box_row, last_box_col;
void set_box(CGContextRef ctx, int row, int col) {
    float x0, y0;
    //fprintf(stderr, "box %d,%d last %d,%d\n", row, col, last_box_row, last_box_col);
    CGContextSetLineWidth(ctx, 2);
    if (last_box_row >= 0) {
        CGContextSetRGBStrokeColor(ctx, cBG, 1.0);
        x0 = 15+1 + last_box_col*43;
        y0 = 11+25+12+last_box_row*43;
        cg_box(ctx, x0, y0, x0+41, y0+41);
    }
    last_box_row = row; last_box_col = col;
        
    CGContextSetRGBStrokeColor(ctx, cBox, 1.0);
    x0 = 15+1 + last_box_col*43;
    y0 = 11+25+12+last_box_row*43;
    cg_box(ctx, x0, y0, x0+41, y0+41);
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

void draw_icon(CGContextRef ctx, pid_t pid, int row, int col) {
    NSImage *icn;
    icn = icon_for_pid(pid);
    
    NSGraphicsContext *gctx = [NSGraphicsContext graphicsContextWithGraphicsPort: ctx flipped: false];

    NSRect icnrect = NSMakeRect(0,0,32,32);
    CGImageRef cgicn = [icn CGImageForProposedRect: &icnrect context: gctx hints: nil];
    CGContextDrawImage(ctx, CGRectMake(15+1+5+col*43, 11+25+12+4+row*43, 32, 32), cgicn);
}

CTFontRef ui_fnt;
int ui_rows, ui_cols;
int draw_icon_row, draw_icon_col;
void draw_window_icon(CFDictionaryRef val, void *ctx) {
    CFNumberRef pidref = CFDictionaryGetValue(val, kCGWindowOwnerPID);
    long pid;
    CFNumberGetValue(pidref, kCFNumberLongType, &pid);
    draw_icon(ctx, pid, draw_icon_row, draw_icon_col);
    if (++draw_icon_col == ui_cols) {
        draw_icon_col = 0;
        draw_icon_row--;
    }
}

void ui_init(void) {
    ui_fnt = CTFontCreateWithName(CFSTR("Tahoma Bold"), 11.0, NULL);
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

    if (action == uiGetSel)
        return selected;

    if (action == uiShow && !showing) {
        showing = 1;
        last_box_col = last_box_row = -1;
        nwind = CFArrayGetCount(windows);
        ui_rows = ((nwind-1) / MAXCOLS) + 1;
        if (ui_rows==1)
            ui_cols = ((nwind-1) % MAXCOLS) + 1;
        else
            ui_cols = MAXCOLS;

        width = 43*ui_cols + 30;
        height = 11+25+28 + 43*ui_rows;
        new_window(&wid, &ctx, width, height);

        shad_box(ctx, 0, 0, 0, width-1, height-1);
        shad_box(ctx, 1, 14, 11, width-14, 11+25);
        icns = [[NSMutableDictionary alloc] init];

        CFRange range = CFRangeMake(0,nwind);
        draw_icon_row = ui_rows - 1;
        draw_icon_col = 0;
        CFArrayApplyFunction(windows, range, (CFArrayApplierFunction)draw_window_icon, ctx); 

        CGSOrderWindow(cid, wid, kCGSOrderAbove, 0);

        selected = 1;
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

    int select_col, select_row;
    CFStringRef title;
        
    select_col = selected % ui_cols;
    select_row = ui_rows - (selected / ui_cols) - 1;

    set_box(ctx, select_row, select_col);
    title = CFDictionaryGetValue(CFArrayGetValueAtIndex(windows, selected), kCGWindowName);
    set_text(ctx, ui_fnt, title, width - 30);
    CGContextFlush(ctx);
    return 0;
}
