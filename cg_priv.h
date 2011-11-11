
typedef void *CGSConnectionID;
typedef void *CGSValue;
typedef enum _CGSWindowOrderingMode {
    kCGSOrderAbove                =  1,
    kCGSOrderBelow                = -1,
    kCGSOrderOut                  =  0
} CGSWindowOrderingMode;
#define kCGSNullConnectionID ((CGSConnectionID)0)

typedef void *CGSRegionRef;
extern CGError CGSNewRegionWithRect(CGRect const *inRect, CGSRegionRef *outRegion);
extern CGError CGSNewEmptyRegion(CGSRegionRef *outRegion);
extern CGError CGSReleaseRegion(CGSRegionRef region);
extern CGContextRef CGWindowContextCreate(CGSConnectionID cid, CGWindowID wid, void *poo);

extern OSStatus CGSGetWindowProperty(CGSConnectionID cid, CGWindowID wid, CGSValue key, CGSValue *outValue);
extern OSStatus CGXGetWindowProperty(CGSConnectionID cid, CGWindowID wid, CGSValue key, CGSValue *outValue);


extern CGError CGSSetWindowLevel(CGSConnectionID cid, CGWindowID wid, CGWindowLevel level);

extern void CGSReleaseGenericObj(CGSValue obj);

extern CGSConnectionID _CGSDefaultConnection(void);
extern OSStatus CGSOrderWindow(CGSConnectionID cid, CGWindowID wid, CGSWindowOrderingMode place, CGWindowID relativeToWindowID /* can be NULL */);

typedef enum {
  CGSTagNone          = 0,        // No tags
  CGSTagExposeFade    = 0x0002,    // Fade out when Expose activates.
  CGSTagNoShadow      = 0x0008,    // No window shadow.
  CGSTagTransparent   = 0x0200,   // Transparent to mouse clicks.
  CGSTagSticky        = 0x0800,    // Appears on all workspaces.
} CGSWindowTag;

extern CGError CGSSetWindowTags(const CGSConnectionID cid, const CGWindowID wid, CGSWindowTag *tags, int thirtyTwo);
extern CGError CGSGetWindowTags(const CGSConnectionID cid, const CGWindowID wid, CGSWindowTag *tags, int thirtyTwo);

extern void CGSAddActivationRegion(CGSConnectionID cid, CGWindowID wid, CGSRegionRef region);
extern void CGSAddDragRegion(CGSConnectionID cid, CGWindowID wid, CGSRegionRef region);
extern void CGSRemoveApplicationSubregion(CGSConnectionID cid, CGWindowID wid, CGSRegionRef region);
extern void CGSGetCurrentCursorLocation(CGSConnectionID cid, CGPoint *loc);
extern void CGSSetMouseFocusWindow(CGSConnectionID cid, CGWindowID wid);
extern void CPSStealKeyFocus(ProcessSerialNumber *psn);
extern void CGSAddDragRegionInWindow(CGSConnectionID cid, CGWindowID wid, CGSRegionRef region);
extern void CGSRemoveDragSubRegionInWindow(CGSConnectionID cid, CGWindowID wid, CGSRegionRef region);

extern void CPSSetFrontProcess(ProcessSerialNumber *psn);
extern void CGSLogStart(int mode);

// additional fields for CGEvent(Set|Get)...ValueField
enum {
    kCGType = 55,
    kCGWindowNumberField = 51,
    kCGTimestamp = 58,
    kCGSubtype = 99,
    kCGFlags = 59
};

