typedef enum {
    uiShow,
    uiHide,
    uiNext,
    uiPrev,
    uiGetSel
} ui_call;

extern CGSConnectionID cid;
extern CFMutableArrayRef windows;

void ui_init(void);
void ui_release(void);
int ui_callback(ui_call action);
