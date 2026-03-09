#!/bin/bash
SRC=/root/localroot/usr/lib/x86_64-linux-gnu
DST=/usr/lib/x86_64-linux-gnu

# Additional X11/cursor/input libs
cp "$SRC/libXcursor.so.1" "$DST/" 2>/dev/null
cp "$SRC/libXcursor.so.1.0.2" "$DST/" 2>/dev/null
cp "$SRC/libXi.so.6" "$DST/" 2>/dev/null
cp "$SRC/libXi.so.6.1.0" "$DST/" 2>/dev/null
cp "$SRC/libXrandr.so.2" "$DST/" 2>/dev/null
cp "$SRC/libXrandr.so.2.2.0" "$DST/" 2>/dev/null
cp "$SRC/libXinerama.so.1" "$DST/" 2>/dev/null
cp "$SRC/libXinerama.so.1.0.0" "$DST/" 2>/dev/null
cp "$SRC/libwayland-cursor.so.0" "$DST/" 2>/dev/null
cp "$SRC/libwayland-cursor.so.0.22.0" "$DST/" 2>/dev/null
cp "$SRC/libxkbcommon.so.0" "$DST/" 2>/dev/null
cp "$SRC/libxkbcommon.so.0.0.0" "$DST/" 2>/dev/null
cp "$SRC/libxkbcommon-x11.so.0" "$DST/" 2>/dev/null
cp "$SRC/libxkbcommon-x11.so.0.0.0" "$DST/" 2>/dev/null
cp "$SRC/libxcb-cursor.so.0" "$DST/" 2>/dev/null
cp "$SRC/libxcb-cursor.so.0.0.0" "$DST/" 2>/dev/null
cp "$SRC/libxcb-icccm.so.4" "$DST/" 2>/dev/null
cp "$SRC/libxcb-icccm.so.4.0.0" "$DST/" 2>/dev/null
cp "$SRC/libxcb-keysyms.so.1" "$DST/" 2>/dev/null
cp "$SRC/libxcb-keysyms.so.1.0.0" "$DST/" 2>/dev/null
cp "$SRC/libxcb-render.so.0" "$DST/" 2>/dev/null
cp "$SRC/libxcb-render.so.0.0.0" "$DST/" 2>/dev/null
cp "$SRC/libxcb-render-util.so.0" "$DST/" 2>/dev/null
cp "$SRC/libxcb-render-util.so.0.0.0" "$DST/" 2>/dev/null
cp "$SRC/libxcb-image.so.0" "$DST/" 2>/dev/null
cp "$SRC/libxcb-image.so.0.0.0" "$DST/" 2>/dev/null
cp "$SRC/libxcb-shape.so.0" "$DST/" 2>/dev/null
cp "$SRC/libxcb-shape.so.0.0.0" "$DST/" 2>/dev/null
cp "$SRC/libxcb-util.so.1" "$DST/" 2>/dev/null
cp "$SRC/libxcb-util.so.1.0.0" "$DST/" 2>/dev/null
cp "$SRC/libxcb-xinerama.so.0" "$DST/" 2>/dev/null
cp "$SRC/libxcb-xinerama.so.0.0.0" "$DST/" 2>/dev/null

echo "Done: copied additional libraries"
