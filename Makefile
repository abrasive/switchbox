SwitchBox.dylib: sb_main.m sb_ui.m
	gcc sb_main.m sb_ui.m -o SwitchBox.dylib -framework AppKit -framework CoreFoundation -framework ApplicationServices -framework Foundation -dynamiclib -init _on_load

run: SwitchBox.dylib
	launchctl unload /System/Library/LaunchAgents/com.apple.Dock.plist
	killall Dock || true
	nohup env "DYLD_INSERT_LIBRARIES=`pwd`/SwitchBox.dylib" open /System/Library/CoreServices/Dock.app &
