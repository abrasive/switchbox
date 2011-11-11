# What?
SwitchBox sets up a key combination (Alt-Tab) to flip between open windows.
Run it:

    make run

Default theme is "high contrast" (hc). Recompile with UI=win32 for the original theme:

    make clean UI=win32 run

# Why...
## ...bother?
OS X only lets you switch between applications, with Command-Tab.
Some applications also let you switch between windows, using (for example) Command-`, but this only works for individual applications.
What I want is a way to switch between all open windows, in most-recently-used order.

Witch is a commercial application that does just that, but to do so, it uses the only officially-sanctioned method - the Accessibility API.
This means that when you hit the hotkey for a window list, it has to talk to every application and ask it what windows it's showing. This means that on even a lightly loaded system, it's slow to respond; and if an app is really slow, then its windows won't show at all.
The other shortcoming of the Accesibility API is that it doesn't deal with X11 applications, at all - a big problem for me, since I tend to be flipping between remote X11 apps and local text editors, terminals etc.

## ...does it clobber the Dock?
The OS X window manager only allows one connection to lord it up and shove around other windows.
That connection belongs to the Dock.

SwitchBox hijacks this magical power by restarting the Dock, injecting itself at startup.

## ...isn't it perfect?
Heh.

Instead of using the sluggish Accessibility API, SwitchBox talks directly to the window manager.
This lets it get information about the windows that are currently open, without asking anyone else, and including X11 windows. This is subject to some simple filtering to remove most junk window objects.

But:

*   Window order information is inferred from their layering.
    
This means that float-on-top windows confuse things a little, as does whole-app (command-tab) switching etc.
*   Some apps create junk that isn't discernible from a real, useful window.

    Microsoft Word, for example, creates lots of annoying clutter. Perhaps a blacklist might come in handy here.
