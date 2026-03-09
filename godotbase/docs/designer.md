# GodotBase - Designer Guide

## Overview

GodotBase is a web-ready Godot template with built-in error reporting and parameter passing from JavaScript.

## Key Features

1. **Error Reporting** - All errors automatically reported to parent window
2. **URL Parameters** - Read parameters from URL (e.g., `?level=5&player=alice`)
3. **JavaScript Communication** - Receive data from embedding webpage in real-time


## Receiving Parameters

### From URL

Parameters can be passed via URL query string:
```
https://yourgame.com/?username=alice&level=5
```

These parameters are automatically parsed and available in the game.

### From JavaScript

The embedding webpage can send parameters to the game at runtime using the JavaScript API.

## Sending Data to Parent Page

The game can send events and data back to the parent webpage via `postMessage`.
