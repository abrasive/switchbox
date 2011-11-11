# default to high contrast UI
UI_CHOSEN=$(patsubst %, sb_ui_%.m, $(if $(UI), $(UI), hc))

SwitchBox.dylib: sb_main.m $(UI_CHOSEN)
	gcc sb_main.m $(UI_CHOSEN) -o SwitchBox.dylib -framework AppKit -framework CoreFoundation -framework ApplicationServices -framework Foundation -dynamiclib -init _on_load

clean:
	rm SwitchBox.dylib

run: SwitchBox.dylib
	launchctl unload /System/Library/LaunchAgents/com.apple.Dock.plist
	killall Dock || true
	env "DYLD_INSERT_LIBRARIES=`pwd`/SwitchBox.dylib" open /System/Library/CoreServices/Dock.app
